# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ConversationViewTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Conversation.Participation
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.ConversationView

  import Pleroma.Factory

  test "represents a Mastodon Conversation entity" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, parent} = CommonAPI.post(user, %{status: "parent"})

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "hey @#{other_user.nickname}",
        visibility: "direct",
        in_reply_to_id: parent.id
      })

    {:ok, _reply_activity} =
      CommonAPI.post(user, %{status: "hu", visibility: "public", in_reply_to_id: parent.id})

    [participation] = Participation.for_user_with_last_activity_id(user)

    assert participation

    conversation =
      ConversationView.render("participation.json", %{participation: participation, for: user})

    assert conversation.id == participation.id |> to_string()
    assert conversation.last_status.id == activity.id
    assert conversation.last_status.account.id == user.id

    assert [account] = conversation.accounts
    assert account.id == other_user.id

    assert conversation.last_status.pleroma.direct_conversation_id == participation.id
  end
end
