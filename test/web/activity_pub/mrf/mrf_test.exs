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

  describe "describe/0" do
    clear_config([:instance, :rewrite_policy])

    test "it works as expected with noop policy" do
      expected = %{
        mrf_policies: ["NoOpPolicy"],
        exclusions: false
      }

      {:ok, ^expected} = MRF.describe()
    end

    test "it works as expected with mock policy" do
      Pleroma.Config.put([:instance, :rewrite_policy], [MRFModuleMock])

      expected = %{
        mrf_policies: ["MRFModuleMock"],
        mrf_module_mock: "some config data",
        exclusions: false
      }

      {:ok, ^expected} = MRF.describe()
    end
  end
end
