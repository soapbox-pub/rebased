# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.KeywordPolicyTest do
  use Pleroma.DataCase

  alias Pleroma.Web.ActivityPub.MRF.KeywordPolicy

  clear_config(:mrf_keyword)

  setup do
    Pleroma.Config.put([:mrf_keyword], %{reject: [], federated_timeline_removal: [], replace: []})
  end

  describe "rejecting based on keywords" do
    test "rejects if string matches in content" do
      Pleroma.Config.put([:mrf_keyword, :reject], ["pun"])

      message = %{
        "type" => "Create",
        "object" => %{
          "content" => "just a daily reminder that compLAINer is a good pun",
          "summary" => ""
        }
      }

      assert {:reject, nil} == KeywordPolicy.filter(message)
    end

    test "rejects if string matches in summary" do
      Pleroma.Config.put([:mrf_keyword, :reject], ["pun"])

      message = %{
        "type" => "Create",
        "object" => %{
          "summary" => "just a daily reminder that compLAINer is a good pun",
          "content" => ""
        }
      }

      assert {:reject, nil} == KeywordPolicy.filter(message)
    end

    test "rejects if regex matches in content" do
      Pleroma.Config.put([:mrf_keyword, :reject], [~r/comp[lL][aA][iI][nN]er/])

      assert true ==
               Enum.all?(["complainer", "compLainer", "compLAiNer", "compLAINer"], fn content ->
                 message = %{
                   "type" => "Create",
                   "object" => %{
                     "content" => "just a daily reminder that #{content} is a good pun",
                     "summary" => ""
                   }
                 }

                 {:reject, nil} == KeywordPolicy.filter(message)
               end)
    end

    test "rejects if regex matches in summary" do
      Pleroma.Config.put([:mrf_keyword, :reject], [~r/comp[lL][aA][iI][nN]er/])

      assert true ==
               Enum.all?(["complainer", "compLainer", "compLAiNer", "compLAINer"], fn content ->
                 message = %{
                   "type" => "Create",
                   "object" => %{
                     "summary" => "just a daily reminder that #{content} is a good pun",
                     "content" => ""
                   }
                 }

                 {:reject, nil} == KeywordPolicy.filter(message)
               end)
    end
  end

  describe "delisting from ftl based on keywords" do
    test "delists if string matches in content" do
      Pleroma.Config.put([:mrf_keyword, :federated_timeline_removal], ["pun"])

      message = %{
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "type" => "Create",
        "object" => %{
          "content" => "just a daily reminder that compLAINer is a good pun",
          "summary" => ""
        }
      }

      {:ok, result} = KeywordPolicy.filter(message)
      assert ["https://www.w3.org/ns/activitystreams#Public"] == result["cc"]
      refute ["https://www.w3.org/ns/activitystreams#Public"] == result["to"]
    end

    test "delists if string matches in summary" do
      Pleroma.Config.put([:mrf_keyword, :federated_timeline_removal], ["pun"])

      message = %{
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "type" => "Create",
        "object" => %{
          "summary" => "just a daily reminder that compLAINer is a good pun",
          "content" => ""
        }
      }

      {:ok, result} = KeywordPolicy.filter(message)
      assert ["https://www.w3.org/ns/activitystreams#Public"] == result["cc"]
      refute ["https://www.w3.org/ns/activitystreams#Public"] == result["to"]
    end

    test "delists if regex matches in content" do
      Pleroma.Config.put([:mrf_keyword, :federated_timeline_removal], [~r/comp[lL][aA][iI][nN]er/])

      assert true ==
               Enum.all?(["complainer", "compLainer", "compLAiNer", "compLAINer"], fn content ->
                 message = %{
                   "type" => "Create",
                   "to" => ["https://www.w3.org/ns/activitystreams#Public"],
                   "object" => %{
                     "content" => "just a daily reminder that #{content} is a good pun",
                     "summary" => ""
                   }
                 }

                 {:ok, result} = KeywordPolicy.filter(message)

                 ["https://www.w3.org/ns/activitystreams#Public"] == result["cc"] and
                   not (["https://www.w3.org/ns/activitystreams#Public"] == result["to"])
               end)
    end

    test "delists if regex matches in summary" do
      Pleroma.Config.put([:mrf_keyword, :federated_timeline_removal], [~r/comp[lL][aA][iI][nN]er/])

      assert true ==
               Enum.all?(["complainer", "compLainer", "compLAiNer", "compLAINer"], fn content ->
                 message = %{
                   "type" => "Create",
                   "to" => ["https://www.w3.org/ns/activitystreams#Public"],
                   "object" => %{
                     "summary" => "just a daily reminder that #{content} is a good pun",
                     "content" => ""
                   }
                 }

                 {:ok, result} = KeywordPolicy.filter(message)

                 ["https://www.w3.org/ns/activitystreams#Public"] == result["cc"] and
                   not (["https://www.w3.org/ns/activitystreams#Public"] == result["to"])
               end)
    end
  end

  describe "replacing keywords" do
    test "replaces keyword if string matches in content" do
      Pleroma.Config.put([:mrf_keyword, :replace], [{"opensource", "free software"}])

      message = %{
        "type" => "Create",
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "object" => %{"content" => "ZFS is opensource", "summary" => ""}
      }

      {:ok, %{"object" => %{"content" => result}}} = KeywordPolicy.filter(message)
      assert result == "ZFS is free software"
    end

    test "replaces keyword if string matches in summary" do
      Pleroma.Config.put([:mrf_keyword, :replace], [{"opensource", "free software"}])

      message = %{
        "type" => "Create",
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "object" => %{"summary" => "ZFS is opensource", "content" => ""}
      }

      {:ok, %{"object" => %{"summary" => result}}} = KeywordPolicy.filter(message)
      assert result == "ZFS is free software"
    end

    test "replaces keyword if regex matches in content" do
      Pleroma.Config.put([:mrf_keyword, :replace], [
        {~r/open(-|\s)?source\s?(software)?/, "free software"}
      ])

      assert true ==
               Enum.all?(["opensource", "open-source", "open source"], fn content ->
                 message = %{
                   "type" => "Create",
                   "to" => ["https://www.w3.org/ns/activitystreams#Public"],
                   "object" => %{"content" => "ZFS is #{content}", "summary" => ""}
                 }

                 {:ok, %{"object" => %{"content" => result}}} = KeywordPolicy.filter(message)
                 result == "ZFS is free software"
               end)
    end

    test "replaces keyword if regex matches in summary" do
      Pleroma.Config.put([:mrf_keyword, :replace], [
        {~r/open(-|\s)?source\s?(software)?/, "free software"}
      ])

      assert true ==
               Enum.all?(["opensource", "open-source", "open source"], fn content ->
                 message = %{
                   "type" => "Create",
                   "to" => ["https://www.w3.org/ns/activitystreams#Public"],
                   "object" => %{"summary" => "ZFS is #{content}", "content" => ""}
                 }

                 {:ok, %{"object" => %{"summary" => result}}} = KeywordPolicy.filter(message)
                 result == "ZFS is free software"
               end)
    end
  end
end
