# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OStatus.OStatusControllerTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.OStatus.ActivityRepresenter

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)

    config_path = [:instance, :federating]
    initial_setting = Pleroma.Config.get(config_path)

    Pleroma.Config.put(config_path, true)
    on_exit(fn -> Pleroma.Config.put(config_path, initial_setting) end)

    :ok
  end

  describe "salmon_incoming" do
    test "decodes a salmon", %{conn: conn} do
      user = insert(:user)
      salmon = File.read!("test/fixtures/salmon.xml")

      conn =
        conn
        |> put_req_header("content-type", "application/atom+xml")
        |> post("/users/#{user.nickname}/salmon", salmon)

      assert response(conn, 200)
    end

    test "decodes a salmon with a changed magic key", %{conn: conn} do
      user = insert(:user)
      salmon = File.read!("test/fixtures/salmon.xml")

      conn =
        conn
        |> put_req_header("content-type", "application/atom+xml")
        |> post("/users/#{user.nickname}/salmon", salmon)

      assert response(conn, 200)

      # Set a wrong magic-key for a user so it has to refetch
      salmon_user = User.get_cached_by_ap_id("http://gs.example.org:4040/index.php/user/1")

      # Wrong key
      info_cng =
        User.Info.remote_user_creation(salmon_user.info, %{
          magic_key:
            "RSA.pu0s-halox4tu7wmES1FVSx6u-4wc0YrUFXcqWXZG4-27UmbCOpMQftRCldNRfyA-qLbz-eqiwrong1EwUvjsD4cYbAHNGHwTvDOyx5AKthQUP44ykPv7kjKGh3DWKySJvcs9tlUG87hlo7AvnMo9pwRS_Zz2CacQ-MKaXyDepk=.AQAB"
        })

      salmon_user
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_embed(:info, info_cng)
      |> User.update_and_set_cache()

      conn =
        build_conn()
        |> put_req_header("content-type", "application/atom+xml")
        |> post("/users/#{user.nickname}/salmon", salmon)

      assert response(conn, 200)
    end
  end

  test "gets a feed", %{conn: conn} do
    note_activity = insert(:note_activity)
    user = User.get_cached_by_ap_id(note_activity.data["actor"])

    conn =
      conn
      |> put_req_header("content-type", "application/atom+xml")
      |> get("/users/#{user.nickname}/feed.atom")

    assert response(conn, 200) =~ note_activity.data["object"]["content"]
  end

  test "returns 404 for a missing feed", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/atom+xml")
      |> get("/users/nonexisting/feed.atom")

    assert response(conn, 404)
  end

  test "gets an object", %{conn: conn} do
    note_activity = insert(:note_activity)
    user = User.get_cached_by_ap_id(note_activity.data["actor"])
    [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["object"]["id"]))
    url = "/objects/#{uuid}"

    conn =
      conn
      |> put_req_header("accept", "application/xml")
      |> get(url)

    expected =
      ActivityRepresenter.to_simple_form(note_activity, user, true)
      |> ActivityRepresenter.wrap_with_entry()
      |> :xmerl.export_simple(:xmerl_xml)
      |> to_string

    assert response(conn, 200) == expected
  end

  test "404s on private objects", %{conn: conn} do
    note_activity = insert(:direct_note_activity)
    [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["object"]["id"]))

    conn
    |> get("/objects/#{uuid}")
    |> response(404)
  end

  test "404s on nonexisting objects", %{conn: conn} do
    conn
    |> get("/objects/123")
    |> response(404)
  end

  test "gets an activity in xml format", %{conn: conn} do
    note_activity = insert(:note_activity)
    [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["id"]))

    conn
    |> put_req_header("accept", "application/xml")
    |> get("/activities/#{uuid}")
    |> response(200)
  end

  test "404s on deleted objects", %{conn: conn} do
    note_activity = insert(:note_activity)
    [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["object"]["id"]))
    object = Object.get_by_ap_id(note_activity.data["object"]["id"])

    conn
    |> put_req_header("accept", "application/xml")
    |> get("/objects/#{uuid}")
    |> response(200)

    Object.delete(object)

    conn
    |> put_req_header("accept", "application/xml")
    |> get("/objects/#{uuid}")
    |> response(404)
  end

  test "404s on private activities", %{conn: conn} do
    note_activity = insert(:direct_note_activity)
    [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["id"]))

    conn
    |> get("/activities/#{uuid}")
    |> response(404)
  end

  test "404s on nonexistent activities", %{conn: conn} do
    conn
    |> get("/activities/123")
    |> response(404)
  end

  test "gets a notice in xml format", %{conn: conn} do
    note_activity = insert(:note_activity)

    conn
    |> get("/notice/#{note_activity.id}")
    |> response(200)
  end

  test "gets a notice in AS2 format", %{conn: conn} do
    note_activity = insert(:note_activity)

    conn
    |> put_req_header("accept", "application/activity+json")
    |> get("/notice/#{note_activity.id}")
    |> json_response(200)
  end

  test "only gets a notice in AS2 format for Create messages", %{conn: conn} do
    note_activity = insert(:note_activity)
    url = "/notice/#{note_activity.id}"

    conn =
      conn
      |> put_req_header("accept", "application/activity+json")
      |> get(url)

    assert json_response(conn, 200)

    user = insert(:user)

    {:ok, like_activity, _} = CommonAPI.favorite(note_activity.id, user)
    url = "/notice/#{like_activity.id}"

    assert like_activity.data["type"] == "Like"

    conn =
      build_conn()
      |> put_req_header("accept", "application/activity+json")
      |> get(url)

    assert response(conn, 404)
  end

  test "gets an activity in AS2 format", %{conn: conn} do
    note_activity = insert(:note_activity)
    [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["id"]))
    url = "/activities/#{uuid}"

    conn =
      conn
      |> put_req_header("accept", "application/activity+json")
      |> get(url)

    assert json_response(conn, 200)
  end

  test "404s a private notice", %{conn: conn} do
    note_activity = insert(:direct_note_activity)
    url = "/notice/#{note_activity.id}"

    conn =
      conn
      |> get(url)

    assert response(conn, 404)
  end

  test "404s a nonexisting notice", %{conn: conn} do
    url = "/notice/123"

    conn =
      conn
      |> get(url)

    assert response(conn, 404)
  end
end
