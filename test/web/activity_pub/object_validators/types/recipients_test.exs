defmodule Pleroma.Web.ObjectValidators.Types.RecipientsTest do
  alias Pleroma.Web.ActivityPub.ObjectValidators.Types.Recipients
  use Pleroma.DataCase

  test "it works with a list" do
    list = ["https://lain.com/users/lain"]
    assert {:ok, list} == Recipients.cast(list)
  end

  test "it turns a single string into a list" do
    recipient = "https://lain.com/users/lain"

    assert {:ok, [recipient]} == Recipients.cast(recipient)
  end
end
