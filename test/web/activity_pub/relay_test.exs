defmodule Pleroma.Web.ActivityPub.RelayTest do
  use Pleroma.DataCase

  alias Pleroma.Web.ActivityPub.Relay

  test "gets an actor for the relay" do
    user = Relay.get_actor()

    assert user.ap_id =~ "/relay"
  end
end
