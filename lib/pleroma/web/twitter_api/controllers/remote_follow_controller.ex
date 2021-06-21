# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.RemoteFollowController do
  use Pleroma.Web, :controller

  require Logger

  alias Pleroma.Activity
  alias Pleroma.MFA
  alias Pleroma.Object.Fetcher
  alias Pleroma.User
  alias Pleroma.Web.Auth.TOTPAuthenticator
  alias Pleroma.Web.Auth.WrapperAuthenticator
  alias Pleroma.Web.CommonAPI

  @status_types ["Article", "Event", "Note", "Video", "Page", "Question"]

  plug(Pleroma.Web.Plugs.FederatingPlug)

  # Note: follower can submit the form (with password auth) not being signed in (having no token)
  plug(
    Pleroma.Web.Plugs.OAuthScopesPlug,
    %{fallback: :proceed_unauthenticated, scopes: ["follow", "write:follows"]}
    when action in [:do_follow]
  )

  # GET /ostatus_subscribe
  #
  def follow(%{assigns: %{user: user}} = conn, %{"acct" => acct}) do
    case is_status?(acct) do
      true -> follow_status(conn, user, acct)
      _ -> follow_account(conn, user, acct)
    end
  end

  defp follow_status(conn, _user, acct) do
    with {:ok, object} <- Fetcher.fetch_object_from_id(acct),
         %Activity{id: activity_id} <- Activity.get_create_by_object_ap_id(object.data["id"]) do
      redirect(conn, to: Routes.o_status_path(conn, :notice, activity_id))
    else
      error ->
        handle_follow_error(conn, error)
    end
  end

  defp follow_account(conn, user, acct) do
    with {:ok, followee} <- User.get_or_fetch(acct) do
      render(conn, follow_template(user), %{error: false, followee: followee, acct: acct})
    else
      {:error, _reason} ->
        render(conn, follow_template(user), %{error: :error})
    end
  end

  defp follow_template(%User{} = _user), do: "follow.html"
  defp follow_template(_), do: "follow_login.html"

  defp is_status?(acct) do
    case Fetcher.fetch_and_contain_remote_object_from_id(acct) do
      {:ok, %{"type" => type}} when type in @status_types ->
        true

      _ ->
        false
    end
  end

  # POST  /ostatus_subscribe
  #
  # adds a remote account in followers if user already is signed in.
  #
  def do_follow(%{assigns: %{user: %User{} = user}} = conn, %{"user" => %{"id" => id}}) do
    with {:fetch_user, %User{} = followee} <- {:fetch_user, User.get_cached_by_id(id)},
         {:ok, _, _, _} <- CommonAPI.follow(user, followee) do
      redirect(conn, to: "/users/#{followee.id}")
    else
      error ->
        handle_follow_error(conn, error)
    end
  end

  # POST  /ostatus_subscribe
  #
  # step 1.
  # checks login\password and displays step 2 form of MFA if need.
  #
  def do_follow(conn, %{"authorization" => %{"name" => _, "password" => _, "id" => id}}) do
    with {_, %User{} = followee} <- {:fetch_user, User.get_cached_by_id(id)},
         {_, {:ok, user}, _} <- {:auth, WrapperAuthenticator.get_user(conn), followee},
         {_, _, _, false} <- {:mfa_required, followee, user, MFA.require?(user)},
         {:ok, _, _, _} <- CommonAPI.follow(user, followee) do
      redirect(conn, to: "/users/#{followee.id}")
    else
      error ->
        handle_follow_error(conn, error)
    end
  end

  # POST  /ostatus_subscribe
  #
  # step 2
  # checks TOTP code. otherwise displays form with errors
  #
  def do_follow(conn, %{"mfa" => %{"code" => code, "token" => token, "id" => id}}) do
    with {_, %User{} = followee} <- {:fetch_user, User.get_cached_by_id(id)},
         {_, _, {:ok, %{user: user}}} <- {:mfa_token, followee, MFA.Token.validate(token)},
         {_, _, _, {:ok, _}} <-
           {:verify_mfa_code, followee, token, TOTPAuthenticator.verify(code, user)},
         {:ok, _, _, _} <- CommonAPI.follow(user, followee) do
      redirect(conn, to: "/users/#{followee.id}")
    else
      error ->
        handle_follow_error(conn, error)
    end
  end

  def do_follow(%{assigns: %{user: nil}} = conn, _) do
    Logger.debug("Insufficient permissions: follow | write:follows.")
    render(conn, "followed.html", %{error: "Insufficient permissions: follow | write:follows."})
  end

  defp handle_follow_error(conn, {:mfa_token, followee, _} = _) do
    render(conn, "follow_login.html", %{error: "Wrong username or password", followee: followee})
  end

  defp handle_follow_error(conn, {:verify_mfa_code, followee, token, _} = _) do
    render(conn, "follow_mfa.html", %{
      error: "Wrong authentication code",
      followee: followee,
      mfa_token: token
    })
  end

  defp handle_follow_error(conn, {:mfa_required, followee, user, _} = _) do
    {:ok, %{token: token}} = MFA.Token.create(user)
    render(conn, "follow_mfa.html", %{followee: followee, mfa_token: token, error: false})
  end

  defp handle_follow_error(conn, {:auth, _, followee} = _) do
    render(conn, "follow_login.html", %{error: "Wrong username or password", followee: followee})
  end

  defp handle_follow_error(conn, {:fetch_user, error} = _) do
    Logger.debug("Remote follow failed with error #{inspect(error)}")
    render(conn, "followed.html", %{error: "Could not find user"})
  end

  defp handle_follow_error(conn, {:error, "Could not follow user:" <> _} = _) do
    render(conn, "followed.html", %{error: "Error following account"})
  end

  defp handle_follow_error(conn, error) do
    Logger.debug("Remote follow failed with error #{inspect(error)}")
    render(conn, "followed.html", %{error: "Something went wrong."})
  end
end
