defmodule Pleroma.Web.PushTest do
  use Pleroma.DataCase

  alias Pleroma.Web.Push

  import Pleroma.Factory

  test "renders body for create activity" do
    assert Push.format_body(
             %{
               activity: %{
                 data: %{
                   "type" => "Create",
                   "object" => %{
                     "content" =>
                       "<span>Lorem ipsum dolor sit amet</span>, consectetur :bear: adipiscing elit. Fusce sagittis finibus turpis."
                   }
                 }
               }
             },
             %{nickname: "Bob"}
           ) ==
             "@Bob: Lorem ipsum dolor sit amet, consectetur  adipiscing elit. Fusce sagittis fini..."
  end

  test "renders body for follow activity" do
    assert Push.format_body(%{activity: %{data: %{"type" => "Follow"}}}, %{nickname: "Bob"}) ==
             "@Bob has followed you"
  end

  test "renders body for announce activity" do
    user = insert(:user)

    note =
      insert(:note, %{
        data: %{
          "content" =>
            "<span>Lorem ipsum dolor sit amet</span>, consectetur :bear: adipiscing elit. Fusce sagittis finibus turpis."
        }
      })

    note_activity = insert(:note_activity, %{note: note})
    announce_activity = insert(:announce_activity, %{user: user, note_activity: note_activity})

    assert Push.format_body(%{activity: announce_activity}, user) ==
             "@#{user.nickname} repeated: Lorem ipsum dolor sit amet, consectetur  adipiscing elit. Fusce sagittis fini..."
  end

  test "renders body for like activity" do
    assert Push.format_body(%{activity: %{data: %{"type" => "Like"}}}, %{nickname: "Bob"}) ==
             "@Bob has favorited your post"
  end
end
