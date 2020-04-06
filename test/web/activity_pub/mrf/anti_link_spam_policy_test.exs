# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.AntiLinkSpamPolicyTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  import ExUnit.CaptureLog

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

  @response_message %{
    "type" => "Create",
    "object" => %{
      "name" => "yes",
      "type" => "Answer"
    }
  }

  describe "with new user" do
    test "it allows posts without links" do
      user = insert(:user)

      assert user.note_count == 0

      message =
        @linkless_message
        |> Map.put("actor", user.ap_id)

      {:ok, _message} = AntiLinkSpamPolicy.filter(message)
    end

    test "it disallows posts with links" do
      user = insert(:user)

      assert user.note_count == 0

      message =
        @linkful_message
        |> Map.put("actor", user.ap_id)

      {:reject, _} = AntiLinkSpamPolicy.filter(message)
    end
  end

  describe "with old user" do
    test "it allows posts without links" do
      user = insert(:user, note_count: 1)

      assert user.note_count == 1

      message =
        @linkless_message
        |> Map.put("actor", user.ap_id)

      {:ok, _message} = AntiLinkSpamPolicy.filter(message)
    end

    test "it allows posts with links" do
      user = insert(:user, note_count: 1)

      assert user.note_count == 1

      message =
        @linkful_message
        |> Map.put("actor", user.ap_id)

      {:ok, _message} = AntiLinkSpamPolicy.filter(message)
    end
  end

  describe "with followed new user" do
    test "it allows posts without links" do
      user = insert(:user, follower_count: 1)

      assert user.follower_count == 1

      message =
        @linkless_message
        |> Map.put("actor", user.ap_id)

      {:ok, _message} = AntiLinkSpamPolicy.filter(message)
    end

    test "it allows posts with links" do
      user = insert(:user, follower_count: 1)

      assert user.follower_count == 1

      message =
        @linkful_message
        |> Map.put("actor", user.ap_id)

      {:ok, _message} = AntiLinkSpamPolicy.filter(message)
    end
  end

  describe "with unknown actors" do
    setup do
      Tesla.Mock.mock(fn
        %{method: :get, url: "http://invalid.actor"} ->
          %Tesla.Env{status: 500, body: ""}
      end)

      :ok
    end

    test "it rejects posts without links" do
      message =
        @linkless_message
        |> Map.put("actor", "http://invalid.actor")

      assert capture_log(fn ->
               {:reject, _} = AntiLinkSpamPolicy.filter(message)
             end) =~ "[error] Could not decode user at fetch http://invalid.actor"
    end

    test "it rejects posts with links" do
      message =
        @linkful_message
        |> Map.put("actor", "http://invalid.actor")

      assert capture_log(fn ->
               {:reject, _} = AntiLinkSpamPolicy.filter(message)
             end) =~ "[error] Could not decode user at fetch http://invalid.actor"
    end
  end

  describe "with contentless-objects" do
    test "it does not reject them or error out" do
      user = insert(:user, note_count: 1)

      message =
        @response_message
        |> Map.put("actor", user.ap_id)

      {:ok, _message} = AntiLinkSpamPolicy.filter(message)
    end
  end
end
