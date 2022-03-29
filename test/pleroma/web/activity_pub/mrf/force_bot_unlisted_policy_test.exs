# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.ForceBotUnlistedPolicyTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory

  alias Pleroma.Web.ActivityPub.MRF.ForceBotUnlistedPolicy
  @public "https://www.w3.org/ns/activitystreams#Public"

  defp generate_messages(actor) do
    {%{
       "actor" => actor.ap_id,
       "type" => "Create",
       "object" => %{},
       "to" => [@public, "f"],
       "cc" => [actor.follower_address, "d"]
     },
     %{
       "actor" => actor.ap_id,
       "type" => "Create",
       "object" => %{"to" => ["f", actor.follower_address], "cc" => ["d", @public]},
       "to" => ["f", actor.follower_address],
       "cc" => ["d", @public]
     }}
  end

  test "removes from the federated timeline by nickname heuristics 1" do
    actor = insert(:user, %{nickname: "annoying_ebooks@example.com"})

    {message, except_message} = generate_messages(actor)

    assert ForceBotUnlistedPolicy.filter(message) == {:ok, except_message}
  end

  test "removes from the federated timeline by nickname heuristics 2" do
    actor = insert(:user, %{nickname: "cirnonewsnetworkbot@meow.cat"})

    {message, except_message} = generate_messages(actor)

    assert ForceBotUnlistedPolicy.filter(message) == {:ok, except_message}
  end

  test "removes from the federated timeline by actor type Application" do
    actor = insert(:user, %{actor_type: "Application"})

    {message, except_message} = generate_messages(actor)

    assert ForceBotUnlistedPolicy.filter(message) == {:ok, except_message}
  end

  test "removes from the federated timeline by actor type Service" do
    actor = insert(:user, %{actor_type: "Service"})

    {message, except_message} = generate_messages(actor)

    assert ForceBotUnlistedPolicy.filter(message) == {:ok, except_message}
  end
end
