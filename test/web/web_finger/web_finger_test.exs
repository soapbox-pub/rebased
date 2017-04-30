defmodule Pleroma.Web.WebFingerTest do
  use Pleroma.DataCase
  alias Pleroma.Web.WebFinger
  import Pleroma.Factory

  describe "host meta" do
    test "returns a link to the xml lrdd" do
      host_info = WebFinger.host_meta()

      assert String.contains?(host_info, Pleroma.Web.base_url)
    end
  end

  describe "fingering" do
    test "returns the info for a user" do
      user = "shp@social.heldscal.la"

      getter = fn(_url, _headers, [params: [resource: ^user]]) ->
        {:ok, %{status_code: 200, body: File.read!("test/fixtures/webfinger.xml")}}
      end

      {:ok, data} = WebFinger.finger(user, getter)

      assert data.magic_key == "RSA.wQ3i9UA0qmAxZ0WTIp4a-waZn_17Ez1pEEmqmqoooRsG1_BvpmOvLN0G2tEcWWxl2KOtdQMCiPptmQObeZeuj48mdsDZ4ArQinexY2hCCTcbV8Xpswpkb8K05RcKipdg07pnI7tAgQ0VWSZDImncL6YUGlG5YN8b5TjGOwk2VG8=.AQAB"
      assert data.topic == "https://social.heldscal.la/api/statuses/user_timeline/29191.atom"
      assert data.subject == "acct:shp@social.heldscal.la"
      assert data.salmon == "https://social.heldscal.la/main/salmon/user/29191"
    end
  end

  describe "ensure_keys_present" do
    test "it creates keys for a user and stores them in info" do
      user = insert(:user)
      refute is_binary(user.info["keys"])
      {:ok, user} = WebFinger.ensure_keys_present(user)
      assert is_binary(user.info["keys"])
    end

    test "it doesn't create keys if there already are some" do
      user = insert(:user, %{info: %{"keys" => "xxx"}})
      {:ok, user} = WebFinger.ensure_keys_present(user)
      assert user.info["keys"] == "xxx"
    end
  end
end
