defmodule Pleroma.ConfigTest do
  use Pleroma.DataCase
  alias Pleroma.Config

  test "get returns the item at the path if there is one" do
    Config.put([:instance, :name], "Plemora")
    assert Config.get([:instance, :name]) == "Plemora"
    assert Config.get([:unknown]) == nil
  end
end
