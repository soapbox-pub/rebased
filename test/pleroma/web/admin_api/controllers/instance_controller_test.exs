# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.InstanceControllerTest do
  use Pleroma.Web.ConnCase, async: false
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory

  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.Web.CommonAPI

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)

    :ok
  end

  setup do
    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  test "GET /instances/:instance/statuses", %{conn: conn} do
    clear_config([:instance, :admin_privileges], [:messages_read])
    user = insert(:user, local: false, ap_id: "https://archae.me/users/archaeme")
    user2 = insert(:user, local: false, ap_id: "https://test.com/users/test")
    insert_pair(:note_activity, user: user)
    activity = insert(:note_activity, user: user2)

    %{"total" => 2, "activities" => activities} =
      conn |> get("/api/pleroma/admin/instances/archae.me/statuses") |> json_response(200)

    assert length(activities) == 2

    %{"total" => 1, "activities" => [_]} =
      conn |> get("/api/pleroma/admin/instances/test.com/statuses") |> json_response(200)

    %{"total" => 0, "activities" => []} =
      conn |> get("/api/pleroma/admin/instances/nonexistent.com/statuses") |> json_response(200)

    CommonAPI.repeat(activity.id, user)

    %{"total" => 2, "activities" => activities} =
      conn |> get("/api/pleroma/admin/instances/archae.me/statuses") |> json_response(200)

    assert length(activities) == 2

    %{"total" => 3, "activities" => activities} =
      conn
      |> get("/api/pleroma/admin/instances/archae.me/statuses?with_reblogs=true")
      |> json_response(200)

    assert length(activities) == 3

    clear_config([:instance, :admin_privileges], [])

    conn |> get("/api/pleroma/admin/instances/archae.me/statuses") |> json_response(:forbidden)
  end

  test "DELETE /instances/:instance", %{conn: conn} do
    clear_config([:instance, :admin_privileges], [:instances_delete])
    user = insert(:user, nickname: "lain@lain.com")
    post = insert(:note_activity, user: user)

    response =
      conn
      |> delete("/api/pleroma/admin/instances/lain.com")
      |> json_response(200)

    [:ok] = ObanHelpers.perform_all()

    assert response == "lain.com"
    refute Repo.reload(user).is_active
    refute Repo.reload(post)

    clear_config([:instance, :admin_privileges], [])

    conn
    |> delete("/api/pleroma/admin/instances/lain.com")
    |> json_response(:forbidden)
  end
end
