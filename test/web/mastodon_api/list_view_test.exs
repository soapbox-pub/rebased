defmodule Pleroma.Web.MastodonAPI.ListViewTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Web.MastodonAPI.ListView
  alias Pleroma.List

  test "Represent a list" do
    user = insert(:user)
    title = "mortal enemies"
    {:ok, list} = Pleroma.List.create(title, user)

    expected = %{
      id: to_string(list.id),
      title: title
    }

    assert expected == ListView.render("list.json", %{list: list})
  end
end
