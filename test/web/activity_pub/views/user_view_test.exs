defmodule Pleroma.Web.ActivityPub.UserViewTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  alias Pleroma.Web.ActivityPub.UserView

  test "Renders a user, including the public key" do
    user = insert(:user)
    {:ok, user} = Pleroma.Web.WebFinger.ensure_keys_present(user)

    result = UserView.render("user.json", %{user: user})

    assert result["id"] == user.ap_id
    assert result["preferredUsername"] == user.nickname

    assert String.contains?(result["publicKey"]["publicKeyPem"], "BEGIN PUBLIC KEY")
  end
end
