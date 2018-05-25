defmodule Pleroma.Web.CommonAPI.Test do
  use Pleroma.DataCase
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  test "it de-duplicates tags" do
    user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{"status" => "#2hu #2HU"})

    assert activity.data["object"]["tag"] == ["2hu"]
  end
end
