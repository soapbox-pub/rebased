# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ListController do
  use Pleroma.Web, :controller

  alias Pleroma.User
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  @oauth_read_actions [:index, :show, :list_accounts]

  plug(Pleroma.Web.ApiSpec.CastAndValidate, replace_params: false)
  plug(:list_by_id_and_user when action not in [:index, :create])
  plug(OAuthScopesPlug, %{scopes: ["read:lists"]} when action in @oauth_read_actions)
  plug(OAuthScopesPlug, %{scopes: ["write:lists"]} when action not in @oauth_read_actions)

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.ListOperation

  # GET /api/v1/lists
  def index(%{assigns: %{user: user}, private: %{open_api_spex: %{params: params}}} = conn, _) do
    lists = Pleroma.List.for_user(user, params)
    render(conn, "index.json", lists: lists)
  end

  # POST /api/v1/lists
  def create(
        %{assigns: %{user: user}, private: %{open_api_spex: %{body_params: %{title: title}}}} =
          conn,
        _
      ) do
    with {:ok, %Pleroma.List{} = list} <- Pleroma.List.create(title, user) do
      render(conn, "show.json", list: list)
    end
  end

  # GET /api/v1/lists/:idOB
  def show(%{assigns: %{list: list}} = conn, _) do
    render(conn, "show.json", list: list)
  end

  # PUT /api/v1/lists/:id
  def update(
        %{assigns: %{list: list}, private: %{open_api_spex: %{body_params: %{title: title}}}} =
          conn,
        _
      ) do
    with {:ok, list} <- Pleroma.List.rename(list, title) do
      render(conn, "show.json", list: list)
    end
  end

  # DELETE /api/v1/lists/:id
  def delete(%{assigns: %{list: list}} = conn, _) do
    with {:ok, _list} <- Pleroma.List.delete(list) do
      json(conn, %{})
    end
  end

  # GET /api/v1/lists/:id/accounts
  def list_accounts(%{assigns: %{user: user, list: list}} = conn, _) do
    with {:ok, users} <- Pleroma.List.get_following(list) do
      conn
      |> put_view(AccountView)
      |> render("index.json", for: user, users: users, as: :user)
    end
  end

  # POST /api/v1/lists/:id/accounts
  def add_to_list(
        %{
          assigns: %{list: list},
          private: %{open_api_spex: %{body_params: %{account_ids: account_ids}}}
        } = conn,
        _
      ) do
    Enum.each(account_ids, fn account_id ->
      with %User{} = followed <- User.get_cached_by_id(account_id) do
        Pleroma.List.follow(list, followed)
      end
    end)

    json(conn, %{})
  end

  # DELETE /api/v1/lists/:id/accounts
  def remove_from_list(
        %{
          private: %{open_api_spex: %{params: %{account_ids: account_ids}}}
        } = conn,
        _
      ) do
    do_remove_from_list(conn, account_ids)
  end

  def remove_from_list(
        %{private: %{open_api_spex: %{body_params: %{account_ids: account_ids}}}} = conn,
        _
      ) do
    do_remove_from_list(conn, account_ids)
  end

  defp do_remove_from_list(%{assigns: %{list: list}} = conn, account_ids) do
    Enum.each(account_ids, fn account_id ->
      with %User{} = followed <- User.get_cached_by_id(account_id) do
        Pleroma.List.unfollow(list, followed)
      end
    end)

    json(conn, %{})
  end

  defp list_by_id_and_user(
         %{assigns: %{user: user}, private: %{open_api_spex: %{params: %{id: id}}}} = conn,
         _
       ) do
    case Pleroma.List.get(id, user) do
      %Pleroma.List{} = list -> assign(conn, :list, list)
      nil -> conn |> render_error(:not_found, "List not found") |> halt()
    end
  end
end
