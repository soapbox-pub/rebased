defmodule Pleroma.Web.OStatus.OStatusControllerTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory
  alias Pleroma.User
  alias Pleroma.Web.OStatus.ActivityRepresenter

  test "gets a feed", %{conn: conn} do
    note_activity = insert(:note_activity)
    user = User.get_cached_by_ap_id(note_activity.data["actor"])

    conn = conn
    |> get("/users/#{user.nickname}/feed.atom")

    assert response(conn, 200)
  end

  test "gets an object", %{conn: conn} do
    note_activity = insert(:note_activity)
    user = User.get_by_ap_id(note_activity.data["actor"])
    [_, uuid] = hd Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["object"]["id"])
    url = "/objects/#{uuid}"

    conn = conn
    |> get(url)

    expected = ActivityRepresenter.to_simple_form(note_activity, user, true)
    |> ActivityRepresenter.wrap_with_entry
    |> :xmerl.export_simple(:xmerl_xml)
    |> to_string

    assert response(conn, 200) == expected
  end

  test "gets an activity", %{conn: conn} do
    note_activity = insert(:note_activity)
    [_, uuid] = hd Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["id"])
    url = "/activities/#{uuid}"

    conn = conn
    |> get(url)

    assert response(conn, 200)
  end
end
