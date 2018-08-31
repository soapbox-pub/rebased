defmodule Pleroma.Web.CommonAPI.Test do
  use Pleroma.DataCase
  alias Pleroma.Web.CommonAPI
  alias Pleroma.User

  import Pleroma.Factory

  test "it de-duplicates tags" do
    user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{"status" => "#2hu #2HU"})

    assert activity.data["object"]["tag"] == ["2hu"]
  end

  test "it adds emoji when updating profiles" do
    user = insert(:user, %{name: ":karjalanpiirakka:"})

    CommonAPI.update(user)
    user = User.get_cached_by_ap_id(user.ap_id)
    [karjalanpiirakka] = user.info["source_data"]["tag"]

    assert karjalanpiirakka["name"] == ":karjalanpiirakka:"
  end
end
