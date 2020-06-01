defmodule Pleroma.Web.ObjectValidators.Types.RecipientsTest do
  alias Pleroma.Web.ActivityPub.ObjectValidators.Types.Recipients
  use Pleroma.DataCase

  test "it asserts that all elements of the list are object ids" do
    list = ["https://lain.com/users/lain", "invalid"]

    assert :error == Recipients.cast(list)
  end

  test "it works with a list" do
    list = ["https://lain.com/users/lain"]
    assert {:ok, list} == Recipients.cast(list)
  end

  test "it works with a list with whole objects" do
    list = ["https://lain.com/users/lain", %{"id" => "https://gensokyo.2hu/users/raymoo"}]
    resulting_list = ["https://gensokyo.2hu/users/raymoo", "https://lain.com/users/lain"]
    assert {:ok, resulting_list} == Recipients.cast(list)
  end

  test "it turns a single string into a list" do
    recipient = "https://lain.com/users/lain"

    assert {:ok, [recipient]} == Recipients.cast(recipient)
  end
end
