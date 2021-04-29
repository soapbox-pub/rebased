# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.HashtagPolicyTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase

  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  test "it sets the sensitive property with relevant hashtags" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "#nsfw hey"})
    {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

    assert modified["object"]["sensitive"]
  end

  test "it doesn't sets the sensitive property with irrelevant hashtags" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "#cofe hey"})
    {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

    refute modified["object"]["sensitive"]
  end
end
