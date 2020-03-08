# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.ActivityPub.MRF.UserAllowListPolicyTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  alias Pleroma.Web.ActivityPub.MRF.UserAllowListPolicy

  clear_config([:mrf_user_allowlist, :localhost])

  test "pass filter if allow list is empty" do
    actor = insert(:user)
    message = %{"actor" => actor.ap_id}
    assert UserAllowListPolicy.filter(message) == {:ok, message}
  end

  test "pass filter if allow list isn't empty and user in allow list" do
    actor = insert(:user)
    Pleroma.Config.put([:mrf_user_allowlist, :localhost], [actor.ap_id, "test-ap-id"])
    message = %{"actor" => actor.ap_id}
    assert UserAllowListPolicy.filter(message) == {:ok, message}
  end

  test "rejected if allow list isn't empty and user not in allow list" do
    actor = insert(:user)
    Pleroma.Config.put([:mrf_user_allowlist, :localhost], ["test-ap-id"])
    message = %{"actor" => actor.ap_id}
    assert UserAllowListPolicy.filter(message) == {:reject, nil}
  end
end
