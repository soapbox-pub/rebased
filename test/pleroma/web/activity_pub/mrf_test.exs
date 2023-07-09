# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRFTest do
  use ExUnit.Case, async: true
  use Pleroma.Tests.Helpers
  alias Pleroma.Web.ActivityPub.MRF

  test "subdomains_regex/1" do
    assert MRF.subdomains_regex(["unsafe.tld", "*.unsafe.tld"]) == [
             ~r/^unsafe.tld$/i,
             ~r/^(.*\.)*unsafe.tld$/i
           ]
  end

  describe "subdomain_match/2" do
    test "common domains" do
      regexes = MRF.subdomains_regex(["unsafe.tld", "unsafe2.tld"])

      assert regexes == [~r/^unsafe.tld$/i, ~r/^unsafe2.tld$/i]

      assert MRF.subdomain_match?(regexes, "unsafe.tld")
      assert MRF.subdomain_match?(regexes, "unsafe2.tld")

      refute MRF.subdomain_match?(regexes, "example.com")
    end

    test "wildcard domains with one subdomain" do
      regexes = MRF.subdomains_regex(["*.unsafe.tld"])

      assert regexes == [~r/^(.*\.)*unsafe.tld$/i]

      assert MRF.subdomain_match?(regexes, "unsafe.tld")
      assert MRF.subdomain_match?(regexes, "sub.unsafe.tld")
      refute MRF.subdomain_match?(regexes, "anotherunsafe.tld")
      refute MRF.subdomain_match?(regexes, "unsafe.tldanother")
    end

    test "wildcard domains with two subdomains" do
      regexes = MRF.subdomains_regex(["*.unsafe.tld"])

      assert regexes == [~r/^(.*\.)*unsafe.tld$/i]

      assert MRF.subdomain_match?(regexes, "unsafe.tld")
      assert MRF.subdomain_match?(regexes, "sub.sub.unsafe.tld")
      refute MRF.subdomain_match?(regexes, "sub.anotherunsafe.tld")
      refute MRF.subdomain_match?(regexes, "sub.unsafe.tldanother")
    end

    test "matches are case-insensitive" do
      regexes = MRF.subdomains_regex(["UnSafe.TLD", "UnSAFE2.Tld"])

      assert regexes == [~r/^UnSafe.TLD$/i, ~r/^UnSAFE2.Tld$/i]

      assert MRF.subdomain_match?(regexes, "UNSAFE.TLD")
      assert MRF.subdomain_match?(regexes, "UNSAFE2.TLD")
      assert MRF.subdomain_match?(regexes, "unsafe.tld")
      assert MRF.subdomain_match?(regexes, "unsafe2.tld")

      refute MRF.subdomain_match?(regexes, "EXAMPLE.COM")
      refute MRF.subdomain_match?(regexes, "example.com")
    end
  end

  describe "instance_list_from_tuples/1" do
    test "returns a list of instances from a list of {instance, reason} tuples" do
      list = [{"some.tld", "a reason"}, {"other.tld", "another reason"}]
      expected = ["some.tld", "other.tld"]

      assert MRF.instance_list_from_tuples(list) == expected
    end

    test "it handles legacy config" do
      list = [{"some.tld", "a reason"}, "other.tld"]
      expected = ["some.tld", "other.tld"]

      assert MRF.instance_list_from_tuples(list) == expected
    end
  end

  describe "normalize_instance_list/1" do
    test "returns a list of tuples" do
      list = [{"some.tld", "a reason"}, "other.tld"]
      expected = [{"some.tld", "a reason"}, {"other.tld", ""}]

      assert MRF.normalize_instance_list(list) == expected
    end
  end

  describe "describe/0" do
    test "it works as expected with noop policy" do
      clear_config([:mrf, :policies], [MRF.NoOpPolicy])

      expected = %{
        mrf_policies: ["NoOpPolicy", "HashtagPolicy"],
        mrf_hashtag: %{
          federated_timeline_removal: [],
          reject: [],
          sensitive: ["nsfw"]
        },
        exclusions: false
      }

      {:ok, ^expected} = MRF.describe()
    end

    test "it works as expected with mock policy" do
      clear_config([:mrf, :policies], [MRFModuleMock])

      expected = %{
        mrf_policies: ["MRFModuleMock", "HashtagPolicy"],
        mrf_module_mock: "some config data",
        mrf_hashtag: %{
          federated_timeline_removal: [],
          reject: [],
          sensitive: ["nsfw"]
        },
        exclusions: false
      }

      {:ok, ^expected} = MRF.describe()
    end

    test "it works as expected with SimplePolicy" do
      clear_config([:mrf, :policies], [MRF.SimplePolicy])
      clear_config([:mrf_simple, :reject], [{"lain.com", "2kool4skool"}, "othersite.xyz"])

      expected = %{
        exclusions: false,
        mrf_hashtag: %{federated_timeline_removal: [], reject: [], sensitive: ["nsfw"]},
        mrf_policies: ["SimplePolicy", "HashtagPolicy"],
        mrf_simple: %{
          accept: [],
          avatar_removal: [],
          banner_removal: [],
          federated_timeline_removal: [],
          followers_only: [],
          media_nsfw: [],
          media_removal: [],
          reject: ["lain.com", "othersite.xyz"],
          reject_deletes: [],
          report_removal: []
        },
        mrf_simple_info: %{reject: %{"lain.com" => %{"reason" => "2kool4skool"}}}
      }

      {:ok, ^expected} = MRF.describe()
    end
  end

  test "config_descriptions/0" do
    descriptions = MRF.config_descriptions()

    good_mrf = Enum.find(descriptions, fn %{key: key} -> key == :good_mrf end)

    assert good_mrf == %{
             key: :good_mrf,
             related_policy: "Fixtures.Modules.GoodMRF",
             label: "Good MRF",
             description: "Some description",
             group: :pleroma,
             tab: :mrf,
             type: :group
           }
  end
end
