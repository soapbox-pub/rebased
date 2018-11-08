defmodule Pleroma.Web.ActivityPub.ObjectViewTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  alias Pleroma.Web.ActivityPub.ObjectView

  test "renders a note object" do
    note = insert(:note)

    result = ObjectView.render("object.json", %{object: note})

    assert result["id"] == note.data["id"]
    assert result["to"] == note.data["to"]
    assert result["content"] == note.data["content"]
    assert result["type"] == "Note"
    assert result["@context"]
  end
end
