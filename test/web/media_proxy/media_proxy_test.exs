# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxyTest do
  use ExUnit.Case
  use Pleroma.Tests.Helpers
  import Pleroma.Web.MediaProxy
  alias Pleroma.Web.MediaProxy.MediaProxyController

  clear_config([:media_proxy, :enabled])

  describe "when enabled" do
    setup do
      Pleroma.Config.put([:media_proxy, :enabled], true)
      :ok
    end

    test "ignores invalid url" do
      assert url(nil) == nil
      assert url("") == nil
    end

    test "ignores relative url" do
      assert url("/local") == "/local"
      assert url("/") == "/"
    end

    test "ignores local url" do
      local_url = Pleroma.Web.Endpoint.url() <> "/hello"
      local_root = Pleroma.Web.Endpoint.url()
      assert url(local_url) == local_url
      assert url(local_root) == local_root
    end

    test "encodes and decodes URL" do
      url = "https://pleroma.soykaf.com/static/logo.png"
      encoded = url(url)

      assert String.starts_with?(
               encoded,
               Pleroma.Config.get([:media_proxy, :base_url], Pleroma.Web.base_url())
             )

      assert String.ends_with?(encoded, "/logo.png")

      assert decode_result(encoded) == url
    end

    test "encodes and decodes URL without a path" do
      url = "https://pleroma.soykaf.com"
      encoded = url(url)
      assert decode_result(encoded) == url
    end

    test "encodes and decodes URL without an extension" do
      url = "https://pleroma.soykaf.com/path/"
      encoded = url(url)
      assert String.ends_with?(encoded, "/path")
      assert decode_result(encoded) == url
    end

    test "encodes and decodes URL and ignores query params for the path" do
      url = "https://pleroma.soykaf.com/static/logo.png?93939393939&bunny=true"
      encoded = url(url)
      assert String.ends_with?(encoded, "/logo.png")
      assert decode_result(encoded) == url
    end

    test "validates signature" do
      secret_key_base = Pleroma.Config.get([Pleroma.Web.Endpoint, :secret_key_base])

      on_exit(fn ->
        Pleroma.Config.put([Pleroma.Web.Endpoint, :secret_key_base], secret_key_base)
      end)

      encoded = url("https://pleroma.social")

      Pleroma.Config.put(
        [Pleroma.Web.Endpoint, :secret_key_base],
        "00000000000000000000000000000000000000000000000"
      )

      [_, "proxy", sig, base64 | _] = URI.parse(encoded).path |> String.split("/")
      assert decode_url(sig, base64) == {:error, :invalid_signature}
    end

    test "filename_matches preserves the encoded or decoded path" do
      assert MediaProxyController.filename_matches(
               %{"filename" => "/Hello world.jpg"},
               "/Hello world.jpg",
               "http://pleroma.social/Hello world.jpg"
             ) == :ok

      assert MediaProxyController.filename_matches(
               %{"filename" => "/Hello%20world.jpg"},
               "/Hello%20world.jpg",
               "http://pleroma.social/Hello%20world.jpg"
             ) == :ok

      assert MediaProxyController.filename_matches(
               %{"filename" => "/my%2Flong%2Furl%2F2019%2F07%2FS.jpg"},
               "/my%2Flong%2Furl%2F2019%2F07%2FS.jpg",
               "http://pleroma.social/my%2Flong%2Furl%2F2019%2F07%2FS.jpg"
             ) == :ok

      assert MediaProxyController.filename_matches(
               %{"filename" => "/my%2Flong%2Furl%2F2019%2F07%2FS.jp"},
               "/my%2Flong%2Furl%2F2019%2F07%2FS.jp",
               "http://pleroma.social/my%2Flong%2Furl%2F2019%2F07%2FS.jpg"
             ) == {:wrong_filename, "my%2Flong%2Furl%2F2019%2F07%2FS.jpg"}
    end

    test "encoded url are tried to match for proxy as `conn.request_path` encodes the url" do
      # conn.request_path will return encoded url
      request_path = "/ANALYSE-DAI-_-LE-STABLECOIN-100-D%C3%89CENTRALIS%C3%89-BQ.jpg"

      assert MediaProxyController.filename_matches(
               true,
               request_path,
               "https://mydomain.com/uploads/2019/07/ANALYSE-DAI-_-LE-STABLECOIN-100-DÉCENTRALISÉ-BQ.jpg"
             ) == :ok
    end

    test "uses the configured base_url" do
      base_url = Pleroma.Config.get([:media_proxy, :base_url])

      if base_url do
        on_exit(fn ->
          Pleroma.Config.put([:media_proxy, :base_url], base_url)
        end)
      end

      Pleroma.Config.put([:media_proxy, :base_url], "https://cache.pleroma.social")

      url = "https://pleroma.soykaf.com/static/logo.png"
      encoded = url(url)

      assert String.starts_with?(encoded, Pleroma.Config.get([:media_proxy, :base_url]))
    end

    # Some sites expect ASCII encoded characters in the URL to be preserved even if
    # unnecessary.
    # Issues: https://git.pleroma.social/pleroma/pleroma/issues/580
    #         https://git.pleroma.social/pleroma/pleroma/issues/1055
    test "preserve ASCII encoding" do
      url =
        "https://pleroma.com/%20/%21/%22/%23/%24/%25/%26/%27/%28/%29/%2A/%2B/%2C/%2D/%2E/%2F/%30/%31/%32/%33/%34/%35/%36/%37/%38/%39/%3A/%3B/%3C/%3D/%3E/%3F/%40/%41/%42/%43/%44/%45/%46/%47/%48/%49/%4A/%4B/%4C/%4D/%4E/%4F/%50/%51/%52/%53/%54/%55/%56/%57/%58/%59/%5A/%5B/%5C/%5D/%5E/%5F/%60/%61/%62/%63/%64/%65/%66/%67/%68/%69/%6A/%6B/%6C/%6D/%6E/%6F/%70/%71/%72/%73/%74/%75/%76/%77/%78/%79/%7A/%7B/%7C/%7D/%7E/%7F/%80/%81/%82/%83/%84/%85/%86/%87/%88/%89/%8A/%8B/%8C/%8D/%8E/%8F/%90/%91/%92/%93/%94/%95/%96/%97/%98/%99/%9A/%9B/%9C/%9D/%9E/%9F/%C2%A0/%A1/%A2/%A3/%A4/%A5/%A6/%A7/%A8/%A9/%AA/%AB/%AC/%C2%AD/%AE/%AF/%B0/%B1/%B2/%B3/%B4/%B5/%B6/%B7/%B8/%B9/%BA/%BB/%BC/%BD/%BE/%BF/%C0/%C1/%C2/%C3/%C4/%C5/%C6/%C7/%C8/%C9/%CA/%CB/%CC/%CD/%CE/%CF/%D0/%D1/%D2/%D3/%D4/%D5/%D6/%D7/%D8/%D9/%DA/%DB/%DC/%DD/%DE/%DF/%E0/%E1/%E2/%E3/%E4/%E5/%E6/%E7/%E8/%E9/%EA/%EB/%EC/%ED/%EE/%EF/%F0/%F1/%F2/%F3/%F4/%F5/%F6/%F7/%F8/%F9/%FA/%FB/%FC/%FD/%FE/%FF"

      encoded = url(url)
      assert decode_result(encoded) == url
    end

    # This includes unsafe/reserved characters which are not interpreted as part of the URL
    # and would otherwise have to be ASCII encoded. It is our role to ensure the proxied URL
    # is unmodified, so we are testing these characters anyway.
    test "preserve non-unicode characters per RFC3986" do
      url =
        "https://pleroma.com/ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890-._~:/?#[]@!$&'()*+,;=|^`{}"

      encoded = url(url)
      assert decode_result(encoded) == url
    end

    test "preserve unicode characters" do
      url = "https://ko.wikipedia.org/wiki/위키백과:대문"

      encoded = url(url)
      assert decode_result(encoded) == url
    end
  end

  describe "when disabled" do
    setup do
      enabled = Pleroma.Config.get([:media_proxy, :enabled])

      if enabled do
        Pleroma.Config.put([:media_proxy, :enabled], false)

        on_exit(fn ->
          Pleroma.Config.put([:media_proxy, :enabled], enabled)
          :ok
        end)
      end

      :ok
    end

    test "does not encode remote urls" do
      assert url("https://google.fr") == "https://google.fr"
    end
  end

  defp decode_result(encoded) do
    [_, "proxy", sig, base64 | _] = URI.parse(encoded).path |> String.split("/")
    {:ok, decoded} = decode_url(sig, base64)
    decoded
  end

  describe "whitelist" do
    setup do
      Pleroma.Config.put([:media_proxy, :enabled], true)
      :ok
    end

    test "mediaproxy whitelist" do
      Pleroma.Config.put([:media_proxy, :whitelist], ["google.com", "feld.me"])
      url = "https://feld.me/foo.png"

      unencoded = url(url)
      assert unencoded == url
    end

    test "does not change whitelisted urls" do
      Pleroma.Config.put([:media_proxy, :whitelist], ["mycdn.akamai.com"])
      Pleroma.Config.put([:media_proxy, :base_url], "https://cache.pleroma.social")

      media_url = "https://mycdn.akamai.com"

      url = "#{media_url}/static/logo.png"
      encoded = url(url)

      assert String.starts_with?(encoded, media_url)
    end

    test "ensure Pleroma.Upload base_url is always whitelisted" do
      upload_config = Pleroma.Config.get([Pleroma.Upload])
      media_url = "https://media.pleroma.social"
      Pleroma.Config.put([Pleroma.Upload, :base_url], media_url)

      url = "#{media_url}/static/logo.png"
      encoded = url(url)

      assert String.starts_with?(encoded, media_url)

      Pleroma.Config.put([Pleroma.Upload], upload_config)
    end
  end
end
