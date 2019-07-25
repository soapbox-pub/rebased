defmodule Pleroma.Web.ActivityPub.MRFTest do
  use ExUnit.Case, async: true
  alias Pleroma.Web.ActivityPub.MRF

  test "subdomains_regex/1" do
    assert MRF.subdomains_regex(["unsafe.tld", "*.unsafe.tld"]) == [
             ~r/^unsafe.tld$/,
             ~r/^(.*\.)*unsafe.tld$/
           ]
  end

  describe "subdomain_match/2" do
    test "common domains" do
      regexes = MRF.subdomains_regex(["unsafe.tld", "unsafe2.tld"])

      assert regexes == [~r/^unsafe.tld$/, ~r/^unsafe2.tld$/]

      assert MRF.subdomain_match?(regexes, "unsafe.tld")
      assert MRF.subdomain_match?(regexes, "unsafe2.tld")

      refute MRF.subdomain_match?(regexes, "example.com")
    end

    test "wildcard domains with one subdomain" do
      regexes = MRF.subdomains_regex(["*.unsafe.tld"])

      assert regexes == [~r/^(.*\.)*unsafe.tld$/]

      assert MRF.subdomain_match?(regexes, "unsafe.tld")
      assert MRF.subdomain_match?(regexes, "sub.unsafe.tld")
      refute MRF.subdomain_match?(regexes, "anotherunsafe.tld")
      refute MRF.subdomain_match?(regexes, "unsafe.tldanother")
    end

    test "wildcard domains with two subdomains" do
      regexes = MRF.subdomains_regex(["*.unsafe.tld"])

      assert regexes == [~r/^(.*\.)*unsafe.tld$/]

      assert MRF.subdomain_match?(regexes, "unsafe.tld")
      assert MRF.subdomain_match?(regexes, "sub.sub.unsafe.tld")
      refute MRF.subdomain_match?(regexes, "sub.anotherunsafe.tld")
      refute MRF.subdomain_match?(regexes, "sub.unsafe.tldanother")
    end
  end
end
