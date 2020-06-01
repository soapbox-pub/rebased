# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.EnsureRePrependedTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.MRF.EnsureRePrepended

  describe "rewrites summary" do
    test "it adds `re:` to summary object when child summary and parent summary equal" do
      message = %{
        "type" => "Create",
        "object" => %{
          "summary" => "object-summary",
          "inReplyTo" => %Activity{object: %Object{data: %{"summary" => "object-summary"}}}
        }
      }

      assert {:ok, res} = EnsureRePrepended.filter(message)
      assert res["object"]["summary"] == "re: object-summary"
    end

    test "it adds `re:` to summary object when child summary containts re-subject of parent summary " do
      message = %{
        "type" => "Create",
        "object" => %{
          "summary" => "object-summary",
          "inReplyTo" => %Activity{object: %Object{data: %{"summary" => "re: object-summary"}}}
        }
      }

      assert {:ok, res} = EnsureRePrepended.filter(message)
      assert res["object"]["summary"] == "re: object-summary"
    end
  end

  describe "skip filter" do
    test "it skip if type isn't 'Create'" do
      message = %{
        "type" => "Annotation",
        "object" => %{"summary" => "object-summary"}
      }

      assert {:ok, res} = EnsureRePrepended.filter(message)
      assert res == message
    end

    test "it skip if summary is empty" do
      message = %{
        "type" => "Create",
        "object" => %{
          "inReplyTo" => %Activity{object: %Object{data: %{"summary" => "summary"}}}
        }
      }

      assert {:ok, res} = EnsureRePrepended.filter(message)
      assert res == message
    end

    test "it skip if inReplyTo is empty" do
      message = %{"type" => "Create", "object" => %{"summary" => "summary"}}
      assert {:ok, res} = EnsureRePrepended.filter(message)
      assert res == message
    end

    test "it skip if parent and child summary isn't equal" do
      message = %{
        "type" => "Create",
        "object" => %{
          "summary" => "object-summary",
          "inReplyTo" => %Activity{object: %Object{data: %{"summary" => "summary"}}}
        }
      }

      assert {:ok, res} = EnsureRePrepended.filter(message)
      assert res == message
    end
  end
end
