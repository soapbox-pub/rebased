# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StreamerViewTest do
  use Pleroma.Web.ConnCase, async: true
  # import ExUnit.CaptureLog
  import Pleroma.Factory

  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.StreamerView

  describe "follow_relationships_update.json" do
    test "shows follower/following count normally" do
      other_user = insert(:user)
      %{id: following_id} = following = insert(:user)
      follower = insert(:user)

      {:ok, _, _, _} = CommonAPI.follow(other_user, following)
      {:ok, following, follower, _activity} = CommonAPI.follow(following, follower)

      result =
        StreamerView.render(
          "follow_relationships_update.json",
          %{follower: follower, following: following, state: :test},
          "user:test"
        )

      {:ok, %{"payload" => payload}} = Jason.decode(result)

      {:ok, decoded_payload} = Jason.decode(payload)

      # check the payload updating the user that was followed
      assert match?(
               %{"follower_count" => 1, "following_count" => 1, "id" => ^following_id},
               decoded_payload["following"]
             )
    end

    test "hides follower count for :hide_followers and :hide_followers_count" do
      user_attrs = [%{hide_followers: true}, %{hide_followers_count: true}]

      Enum.each(user_attrs, fn attrs ->
        other_user = insert(:user)
        %{id: following_id} = following = insert(:user, attrs)
        follower = insert(:user)

        {:ok, _, _, _} = CommonAPI.follow(other_user, following)
        {:ok, following, follower, _activity} = CommonAPI.follow(following, follower)

        result =
          StreamerView.render(
            "follow_relationships_update.json",
            %{follower: follower, following: following, state: :test},
            "user:test"
          )

        {:ok, %{"payload" => payload}} = Jason.decode(result)

        {:ok, decoded_payload} = Jason.decode(payload)

        # check the payload updating the user that was followed
        assert match?(
                 %{"follower_count" => 0, "following_count" => 1, "id" => ^following_id},
                 decoded_payload["following"]
               )
      end)
    end

    test "hides follows count for :hide_follows and :hide_follows_count" do
      user_attrs = [%{hide_follows: true}, %{hide_follows_count: true}]

      Enum.each(user_attrs, fn attrs ->
        other_user = insert(:user)
        %{id: following_id} = following = insert(:user, attrs)
        follower = insert(:user)

        {:ok, _, _, _} = CommonAPI.follow(other_user, following)
        {:ok, following, follower, _activity} = CommonAPI.follow(following, follower)

        result =
          StreamerView.render(
            "follow_relationships_update.json",
            %{follower: follower, following: following, state: :test},
            "user:test"
          )

        {:ok, %{"payload" => payload}} = Jason.decode(result)

        {:ok, decoded_payload} = Jason.decode(payload)

        # check the payload updating the user that was followed
        assert match?(
                 %{"follower_count" => 1, "following_count" => 0, "id" => ^following_id},
                 decoded_payload["following"]
               )
      end)
    end
  end
end
