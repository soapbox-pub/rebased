# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.AntiLinkSpamPolicyTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  alias Pleroma.Web.ActivityPub.MRF.AntiLinkSpamPolicy

  @linkless_message %{
    "type" => "Create",
    "object" => %{
      "content" => "hi world!"
    }
  }

  @linkful_message %{
    "type" => "Create",
    "object" => %{
      "content" => "<a href='https://example.com'>hi world!</a>"
    }
  }

  describe "with new user" do
    test "it allows posts without links" do
      user = insert(:user)

      assert user.info.note_count == 0

      message =
        @linkless_message
        |> Map.put("actor", user.ap_id)

      {:ok, _message} = AntiLinkSpamPolicy.filter(message)
    end

    test "it disallows posts with links" do
      user = insert(:user)

      assert user.info.note_count == 0

      message =
        @linkful_message
        |> Map.put("actor", user.ap_id)

      {:reject, _} = AntiLinkSpamPolicy.filter(message)
    end
  end

  describe "with old user" do
    test "it allows posts without links" do
      user = insert(:user, info: %{note_count: 1})

      assert user.info.note_count == 1

      message =
        @linkless_message
        |> Map.put("actor", user.ap_id)

      {:ok, _message} = AntiLinkSpamPolicy.filter(message)
    end

    test "it allows posts with links" do
      user = insert(:user, info: %{note_count: 1})

      assert user.info.note_count == 1

      message =
        @linkful_message
        |> Map.put("actor", user.ap_id)

      {:ok, _message} = AntiLinkSpamPolicy.filter(message)
    end
  end

  describe "with followed new user" do
    test "it allows posts without links" do
      user = insert(:user, info: %{follower_count: 1})

      assert user.info.follower_count == 1

      message =
        @linkless_message
        |> Map.put("actor", user.ap_id)

      {:ok, _message} = AntiLinkSpamPolicy.filter(message)
    end

    test "it allows posts with links" do
      user = insert(:user, info: %{follower_count: 1})

      assert user.info.follower_count == 1

      message =
        @linkful_message
        |> Map.put("actor", user.ap_id)

      {:ok, _message} = AntiLinkSpamPolicy.filter(message)
    end
  end

  describe "with unknown actors" do
    test "it rejects posts without links" do
      message =
        @linkless_message
        |> Map.put("actor", "http://invalid.actor")

      {:reject, _} = AntiLinkSpamPolicy.filter(message)
    end

    test "it rejects posts with links" do
      message =
        @linkful_message
        |> Map.put("actor", "http://invalid.actor")

      {:reject, _} = AntiLinkSpamPolicy.filter(message)
    end
  end
end
