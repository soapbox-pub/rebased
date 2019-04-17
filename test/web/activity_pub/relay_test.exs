# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.RelayTest do
  use Pleroma.DataCase

  alias Pleroma.Web.ActivityPub.Relay

  test "gets an actor for the relay" do
    user = Relay.get_actor()

    assert user.ap_id =~ "/relay"
  end
end
