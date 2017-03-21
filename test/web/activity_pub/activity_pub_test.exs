defmodule Pleroma.Web.ActivityPub.ActivityPubTest do
  use Pleroma.DataCase
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Activity

  describe "insertion" do
    test "inserts a given map into the activity database" do
      data = %{
        ok: true
      }

      {:ok, %Activity{} = activity} = ActivityPub.insert(data)
      assert activity.data == data
    end
  end

end
