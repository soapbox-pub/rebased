defmodule Pleroma.Web.CommonAPI.Test do
  use Pleroma.DataCase
  alias Pleroma.Web.CommonAPI
  alias Pleroma.User
  alias Pleroma.Activity

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

      content = activity.data["object"]["content"]
      assert content == "<p><b>2hu</b></p>alert('xss')"
    end

    test "it filters out obviously bad tags when accepting a post as Markdown" do
      user = insert(:user)

      post = "<p><b>2hu</b></p><script>alert('xss')</script>"

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => post,
          "content_type" => "text/markdown"
        })

      content = activity.data["object"]["content"]
      assert content == "<p><b>2hu</b></p>alert('xss')"
    end
  end

  describe "reactions" do
    test "repeating a status" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(other_user, %{"status" => "cofe"})

      {:ok, %Activity{}, _} = CommonAPI.repeat(activity.id, user)
    end

    test "favoriting a status" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(other_user, %{"status" => "cofe"})

      {:ok, %Activity{}, _} = CommonAPI.favorite(activity.id, user)
    end

    test "retweeting a status twice returns an error" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(other_user, %{"status" => "cofe"})
      {:ok, %Activity{}, _object} = CommonAPI.repeat(activity.id, user)
      {:error, _} = CommonAPI.repeat(activity.id, user)
    end

    test "favoriting a status twice returns an error" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(other_user, %{"status" => "cofe"})
      {:ok, %Activity{}, _object} = CommonAPI.favorite(activity.id, user)
      {:error, _} = CommonAPI.favorite(activity.id, user)
    end
  end
end
