# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.InstanceController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [fetch_integer_param: 3]

  alias Pleroma.Instances.Instance
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.AdminAPI
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  require Logger

  @default_page_size 50

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:read:statuses"]}
    when action in [:list_statuses]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:write:accounts", "admin:write:statuses"]}
    when action in [:delete]
  )

  action_fallback(AdminAPI.FallbackController)

  def list_statuses(conn, %{"instance" => instance} = params) do
    with_reblogs = params["with_reblogs"] == "true" || params["with_reblogs"] == true
    {page, page_size} = page_params(params)

    result =
      ActivityPub.fetch_statuses(nil, %{
        instance: instance,
        limit: page_size,
        offset: (page - 1) * page_size,
        exclude_reblogs: not with_reblogs,
        total: true
      })

    conn
    |> put_view(AdminAPI.StatusView)
    |> render("index.json", %{total: result[:total], activities: result[:items], as: :activity})
  end

  def delete(conn, %{"instance" => instance}) do
    with {:ok, _job} <- Instance.delete_users_and_activities(instance) do
      json(conn, instance)
    end
  end

  defp page_params(params) do
    {
      fetch_integer_param(params, "page", 1),
      fetch_integer_param(params, "page_size", @default_page_size)
    }
  end
end
