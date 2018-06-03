defmodule Pleroma.Web.OStatus.OStatusControllerTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory
  alias Pleroma.{User, Repo}
  alias Pleroma.Web.OStatus.ActivityRepresenter

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
    salmon_user = User.get_by_ap_id("http://gs.example.org:4040/index.php/user/1")
    # Wrong key
    info =
      salmon_user.info
      |> Map.put(
        "magic_key",
        "RSA.pu0s-halox4tu7wmES1FVSx6u-4wc0YrUFXcqWXZG4-27UmbCOpMQftRCldNRfyA-qLbz-eqiwrong1EwUvjsD4cYbAHNGHwTvDOyx5AKthQUP44ykPv7kjKGh3DWKySJvcs9tlUG87hlo7AvnMo9pwRS_Zz2CacQ-MKaXyDepk=.AQAB"
      )

    Repo.update(User.info_changeset(salmon_user, %{info: info}))

    conn =
      build_conn()
      |> put_req_header("content-type", "application/atom+xml")
      |> post("/users/#{user.nickname}/salmon", salmon)

    assert response(conn, 200)
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
    user = User.get_by_ap_id(note_activity.data["actor"])
    [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["object"]["id"]))
    url = "/objects/#{uuid}"

    conn =
      conn
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
    user = User.get_by_ap_id(note_activity.data["actor"])
    [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["object"]["id"]))
    url = "/objects/#{uuid}"

    conn =
      conn
      |> get(url)

    assert response(conn, 404)
  end

  test "404s on nonexisting objects", %{conn: conn} do
    url = "/objects/123"

    conn =
      conn
      |> get(url)

    assert response(conn, 404)
  end

  test "gets an activity", %{conn: conn} do
    note_activity = insert(:note_activity)
    [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["id"]))
    url = "/activities/#{uuid}"

    conn =
      conn
      |> get(url)

    assert response(conn, 200)
  end

  test "404s on private activities", %{conn: conn} do
    note_activity = insert(:direct_note_activity)
    [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["id"]))
    url = "/activities/#{uuid}"

    conn =
      conn
      |> get(url)

    assert response(conn, 404)
  end

  test "404s on nonexistent activities", %{conn: conn} do
    url = "/activities/123"

    conn =
      conn
      |> get(url)

    assert response(conn, 404)
  end

  test "gets a notice", %{conn: conn} do
    note_activity = insert(:note_activity)
    url = "/notice/#{note_activity.id}"

    conn =
      conn
      |> get(url)

    assert response(conn, 200)
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
