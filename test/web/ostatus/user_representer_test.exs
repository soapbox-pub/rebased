defmodule Pleroma.Web.OStatus.UserRepresenterTest do
  use Pleroma.DataCase
  alias Pleroma.Web.OStatus.UserRepresenter

  import Pleroma.Factory

  test "returns a user with id, uri, name and link" do
    user = build(:user)
    tuple = UserRepresenter.to_tuple(user)
    {:author, author} = tuple

    [:id, :uri, :name, :link]
    |> Enum.each(fn (tag) ->
      assert Enum.find(author, fn(e) -> tag == elem(e, 0) end)
    end)
  end
end
