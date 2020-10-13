# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.UserController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [fetch_integer_param: 3]

  alias Pleroma.ModerationLog
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.Pipeline
  alias Pleroma.Web.AdminAPI
  alias Pleroma.Web.AdminAPI.AccountView
  alias Pleroma.Web.AdminAPI.Search
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  @users_page_size 50

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:accounts"], admin: true}
    when action in [:list, :show]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:accounts"], admin: true}
    when action in [
           :delete,
           :create,
           :toggle_activation,
           :activate,
           :deactivate,
           :approve
         ]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:follows"], admin: true}
    when action in [:follow, :unfollow]
  )

  action_fallback(AdminAPI.FallbackController)

  def delete(conn, %{"nickname" => nickname}) do
    delete(conn, %{"nicknames" => [nickname]})
  end

  def delete(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames}) do
    users = Enum.map(nicknames, &User.get_cached_by_nickname/1)

    Enum.each(users, fn user ->
      {:ok, delete_data, _} = Builder.delete(admin, user.ap_id)
      Pipeline.common_pipeline(delete_data, local: true)
    end)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: users,
      action: "delete"
    })

    json(conn, nicknames)
  end

  def follow(%{assigns: %{user: admin}} = conn, %{
        "follower" => follower_nick,
        "followed" => followed_nick
      }) do
    with %User{} = follower <- User.get_cached_by_nickname(follower_nick),
         %User{} = followed <- User.get_cached_by_nickname(followed_nick) do
      User.follow(follower, followed)

      ModerationLog.insert_log(%{
        actor: admin,
        followed: followed,
        follower: follower,
        action: "follow"
      })
    end

    json(conn, "ok")
  end

  def unfollow(%{assigns: %{user: admin}} = conn, %{
        "follower" => follower_nick,
        "followed" => followed_nick
      }) do
    with %User{} = follower <- User.get_cached_by_nickname(follower_nick),
         %User{} = followed <- User.get_cached_by_nickname(followed_nick) do
      User.unfollow(follower, followed)

      ModerationLog.insert_log(%{
        actor: admin,
        followed: followed,
        follower: follower,
        action: "unfollow"
      })
    end

    json(conn, "ok")
  end

  def create(%{assigns: %{user: admin}} = conn, %{"users" => users}) do
    changesets =
      Enum.map(users, fn %{"nickname" => nickname, "email" => email, "password" => password} ->
        user_data = %{
          nickname: nickname,
          name: nickname,
          email: email,
          password: password,
          password_confirmation: password,
          bio: "."
        }

        User.register_changeset(%User{}, user_data, need_confirmation: false)
      end)
      |> Enum.reduce(Ecto.Multi.new(), fn changeset, multi ->
        Ecto.Multi.insert(multi, Ecto.UUID.generate(), changeset)
      end)

    case Pleroma.Repo.transaction(changesets) do
      {:ok, users} ->
        res =
          users
          |> Map.values()
          |> Enum.map(fn user ->
            {:ok, user} = User.post_register_action(user)

            user
          end)
          |> Enum.map(&AccountView.render("created.json", %{user: &1}))

        ModerationLog.insert_log(%{
          actor: admin,
          subjects: Map.values(users),
          action: "create"
        })

        json(conn, res)

      {:error, id, changeset, _} ->
        res =
          Enum.map(changesets.operations, fn
            {current_id, {:changeset, _current_changeset, _}} when current_id == id ->
              AccountView.render("create-error.json", %{changeset: changeset})

            {_, {:changeset, current_changeset, _}} ->
              AccountView.render("create-error.json", %{changeset: current_changeset})
          end)

        conn
        |> put_status(:conflict)
        |> json(res)
    end
  end

  def show(%{assigns: %{user: admin}} = conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_cached_by_nickname_or_id(nickname, for: admin) do
      conn
      |> put_view(AccountView)
      |> render("show.json", %{user: user})
    else
      _ -> {:error, :not_found}
    end
  end

  def toggle_activation(%{assigns: %{user: admin}} = conn, %{"nickname" => nickname}) do
    user = User.get_cached_by_nickname(nickname)

    {:ok, updated_user} = User.set_activation(user, !user.is_active)

    action = if !user.is_active, do: "activate", else: "deactivate"

    ModerationLog.insert_log(%{
      actor: admin,
      subject: [user],
      action: action
    })

    conn
    |> put_view(AccountView)
    |> render("show.json", %{user: updated_user})
  end

  def activate(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames}) do
    users = Enum.map(nicknames, &User.get_cached_by_nickname/1)
    {:ok, updated_users} = User.set_activation(users, true)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: users,
      action: "activate"
    })

    conn
    |> put_view(AccountView)
    |> render("index.json", %{users: Keyword.values(updated_users)})
  end

  def deactivate(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames}) do
    users = Enum.map(nicknames, &User.get_cached_by_nickname/1)
    {:ok, updated_users} = User.set_activation(users, false)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: users,
      action: "deactivate"
    })

    conn
    |> put_view(AccountView)
    |> render("index.json", %{users: Keyword.values(updated_users)})
  end

  def approve(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames}) do
    users = Enum.map(nicknames, &User.get_cached_by_nickname/1)
    {:ok, updated_users} = User.approve(users)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: users,
      action: "approve"
    })

    conn
    |> put_view(AccountView)
    |> render("index.json", %{users: updated_users})
  end

  def list(conn, params) do
    {page, page_size} = page_params(params)
    filters = maybe_parse_filters(params["filters"])

    search_params =
      %{
        query: params["query"],
        page: page,
        page_size: page_size,
        tags: params["tags"],
        name: params["name"],
        email: params["email"],
        actor_types: params["actor_types"]
      }
      |> Map.merge(filters)

    with {:ok, users, count} <- Search.user(search_params) do
      json(
        conn,
        AccountView.render("index.json",
          users: users,
          count: count,
          page_size: page_size
        )
      )
    end
  end

  @filters ~w(local external active deactivated need_approval unconfirmed is_admin is_moderator)

  @spec maybe_parse_filters(String.t()) :: %{required(String.t()) => true} | %{}
  defp maybe_parse_filters(filters) when is_nil(filters) or filters == "", do: %{}

  defp maybe_parse_filters(filters) do
    filters
    |> String.split(",")
    |> Enum.filter(&Enum.member?(@filters, &1))
    |> Map.new(&{String.to_existing_atom(&1), true})
  end

  defp page_params(params) do
    {
      fetch_integer_param(params, "page", 1),
      fetch_integer_param(params, "page_size", @users_page_size)
    }
  end
end
