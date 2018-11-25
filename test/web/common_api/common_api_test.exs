defmodule Pleroma.Web.CommonAPI.Test do
  use Pleroma.DataCase
  alias Pleroma.Web.CommonAPI
  alias Pleroma.{User, Object}

  import Pleroma.Factory

  test "it de-duplicates tags" do
    user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{"status" => "#2hu #2HU"})

    object = Object.normalize(activity.data["object"])

    assert object.data["tag"] == ["2hu"]
  end

  test "it adds emoji when updating profiles" do
    user = insert(:user, %{name: ":karjalanpiirakka:"})

    CommonAPI.update(user)
    user = User.get_cached_by_ap_id(user.ap_id)
    [karjalanpiirakka] = user.info.source_data["tag"]

    assert karjalanpiirakka["name"] == ":karjalanpiirakka:"
  end

  describe "posting" do
    test "it filters out obviously bad tags when accepting a post as HTML" do
      user = insert(:user)

      post = "<p><b>2hu</b></p><script>alert('xss')</script>"

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => post,
          "content_type" => "text/html"
        })

      object = Object.normalize(activity.data["object"])

      assert object.data["content"] == "<p><b>2hu</b></p>alert('xss')"
    end

    test "it filters out obviously bad tags when accepting a post as Markdown" do
      user = insert(:user)

      post = "<p><b>2hu</b></p><script>alert('xss')</script>"

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => post,
          "content_type" => "text/markdown"
        })

      object = Object.normalize(activity.data["object"])

      assert object.data["content"] == "<p><b>2hu</b></p>alert('xss')"
    end
  end
end
