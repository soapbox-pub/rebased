# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.SubchainPolicyTest do
  use Pleroma.DataCase

  alias Pleroma.Web.ActivityPub.MRF.DropPolicy
  alias Pleroma.Web.ActivityPub.MRF.SubchainPolicy

  @message %{
    "actor" => "https://banned.com",
    "type" => "Create",
    "object" => %{"content" => "hi"}
  }

  clear_config([:mrf_subchain, :match_actor])

  test "it matches and processes subchains when the actor matches a configured target" do
    Pleroma.Config.put([:mrf_subchain, :match_actor], %{
      ~r/^https:\/\/banned.com/s => [DropPolicy]
    })

    {:reject, _} = SubchainPolicy.filter(@message)
  end

  test "it doesn't match and process subchains when the actor doesn't match a configured target" do
    Pleroma.Config.put([:mrf_subchain, :match_actor], %{
      ~r/^https:\/\/borked.com/s => [DropPolicy]
    })

    {:ok, _message} = SubchainPolicy.filter(@message)
  end
end
