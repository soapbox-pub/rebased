# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.StatusController do
  use Pleroma.Web, :controller

  alias Pleroma.Activity
  alias Pleroma.ModerationLog
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI

  require Logger

  @users_page_size 50

  plug(OAuthScopesPlug, %{scopes: ["read:statuses"], admin: true} when action in [:index, :show])

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:statuses"], admin: true} when action in [:update, :delete]
  )

  action_fallback(Pleroma.Web.AdminAPI.FallbackController)

  def index(%{assigns: %{user: _admin}} = conn, params) do
    godmode = params["godmode"] == "true" || params["godmode"] == true
    local_only = params["local_only"] == "true" || params["local_only"] == true
    with_reblogs = params["with_reblogs"] == "true" || params["with_reblogs"] == true
    {page, page_size} = page_params(params)

    activities =
      ActivityPub.fetch_statuses(nil, %{
        "godmode" => godmode,
        "local_only" => local_only,
        "limit" => page_size,
        "offset" => (page - 1) * page_size,
        "exclude_reblogs" => !with_reblogs && "true"
      })

    render(conn, "index.json", %{activities: activities, as: :activity})
  end

  def show(conn, %{"id" => id}) do
    with %Activity{} = activity <- Activity.get_by_id(id) do
      conn
      |> put_view(MastodonAPI.StatusView)
      |> render("show.json", %{activity: activity})
    else
      nil -> {:error, :not_found}
    end
  end

  def update(%{assigns: %{user: admin}} = conn, %{"id" => id} = params) do
    params =
      params
      |> Map.take(["sensitive", "visibility"])
      |> Map.new(fn {key, value} -> {String.to_existing_atom(key), value} end)

    with {:ok, activity} <- CommonAPI.update_activity_scope(id, params) do
      {:ok, sensitive} = Ecto.Type.cast(:boolean, params[:sensitive])

      ModerationLog.insert_log(%{
        action: "status_update",
        actor: admin,
        subject: activity,
        sensitive: sensitive,
        visibility: params[:visibility]
      })

      conn
      |> put_view(MastodonAPI.StatusView)
      |> render("show.json", %{activity: activity})
    end
  end

  def delete(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with {:ok, %Activity{}} <- CommonAPI.delete(id, user) do
      ModerationLog.insert_log(%{
        action: "status_delete",
        actor: user,
        subject_id: id
      })

      json(conn, %{})
    end
  end

  defp page_params(params) do
    {get_page(params["page"]), get_page_size(params["page_size"])}
  end

  defp get_page(page_string) when is_nil(page_string), do: 1

  defp get_page(page_string) do
    case Integer.parse(page_string) do
      {page, _} -> page
      :error -> 1
    end
  end

  defp get_page_size(page_size_string) when is_nil(page_size_string), do: @users_page_size

  defp get_page_size(page_size_string) do
    case Integer.parse(page_size_string) do
      {page_size, _} -> page_size
      :error -> @users_page_size
    end
  end
end
