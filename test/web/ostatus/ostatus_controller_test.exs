defmodule Pleroma.Web.OStatus.OStatusControllerTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory
  alias Pleroma.User

  test "gets a feed", %{conn: conn} do
    note_activity = insert(:note_activity)
    user = User.get_cached_by_ap_id(note_activity.data["actor"])

    conn = conn
    |> get("/users/#{user.nickname}/feed.atom")

    assert response(conn, 200)
  end
end
