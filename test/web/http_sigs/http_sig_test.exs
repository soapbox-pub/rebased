# http signatures
# Test data from https://tools.ietf.org/html/draft-cavage-http-signatures-08#appendix-C
defmodule Pleroma.Web.HTTPSignaturesTest do
  use Pleroma.DataCase
  alias Pleroma.Web.HTTPSignatures
  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  @public_key hd(:public_key.pem_decode(File.read!("test/web/http_sigs/pub.key")))
              |> :public_key.pem_entry_decode()

  @headers %{
    "(request-target)" => "post /foo?param=value&pet=dog",
    "host" => "example.com",
    "date" => "Thu, 05 Jan 2014 21:31:40 GMT",
    "content-type" => "application/json",
    "digest" => "SHA-256=X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=",
    "content-length" => "18"
  }

  @default_signature """
  keyId="Test",algorithm="rsa-sha256",signature="jKyvPcxB4JbmYY4mByyBY7cZfNl4OW9HpFQlG7N4YcJPteKTu4MWCLyk+gIr0wDgqtLWf9NLpMAMimdfsH7FSWGfbMFSrsVTHNTk0rK3usrfFnti1dxsM4jl0kYJCKTGI/UWkqiaxwNiKqGcdlEDrTcUhhsFsOIo8VhddmZTZ8w="
  """

  @basic_signature """
  keyId="Test",algorithm="rsa-sha256",headers="(request-target) host date",signature="HUxc9BS3P/kPhSmJo+0pQ4IsCo007vkv6bUm4Qehrx+B1Eo4Mq5/6KylET72ZpMUS80XvjlOPjKzxfeTQj4DiKbAzwJAb4HX3qX6obQTa00/qPDXlMepD2JtTw33yNnm/0xV7fQuvILN/ys+378Ysi082+4xBQFwvhNvSoVsGv4="
  """

  @all_headers_signature """
  keyId="Test",algorithm="rsa-sha256",headers="(request-target) host date content-type digest content-length",signature="Ef7MlxLXoBovhil3AlyjtBwAL9g4TN3tibLj7uuNB3CROat/9KaeQ4hW2NiJ+pZ6HQEOx9vYZAyi+7cmIkmJszJCut5kQLAwuX+Ms/mUFvpKlSo9StS2bMXDBNjOh4Auj774GFj4gwjS+3NhFeoqyr/MuN6HsEnkvn6zdgfE2i0="
  """

  test "split up a signature" do
    expected = %{
      "keyId" => "Test",
      "algorithm" => "rsa-sha256",
      "signature" =>
        "jKyvPcxB4JbmYY4mByyBY7cZfNl4OW9HpFQlG7N4YcJPteKTu4MWCLyk+gIr0wDgqtLWf9NLpMAMimdfsH7FSWGfbMFSrsVTHNTk0rK3usrfFnti1dxsM4jl0kYJCKTGI/UWkqiaxwNiKqGcdlEDrTcUhhsFsOIo8VhddmZTZ8w=",
      "headers" => ["date"]
    }

    assert HTTPSignatures.split_signature(@default_signature) == expected
  end

  test "validates the default case" do
    signature = HTTPSignatures.split_signature(@default_signature)
    assert HTTPSignatures.validate(@headers, signature, @public_key)
  end

  test "validates the basic case" do
    signature = HTTPSignatures.split_signature(@basic_signature)
    assert HTTPSignatures.validate(@headers, signature, @public_key)
  end

  test "validates the all-headers case" do
    signature = HTTPSignatures.split_signature(@all_headers_signature)
    assert HTTPSignatures.validate(@headers, signature, @public_key)
  end

  test "it contructs a signing string" do
    expected = "date: Thu, 05 Jan 2014 21:31:40 GMT\ncontent-length: 18"
    assert expected == HTTPSignatures.build_signing_string(@headers, ["date", "content-length"])
  end

  test "it validates a conn" do
    public_key_pem =
      "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnGb42rPZIapY4Hfhxrgn\nxKVJczBkfDviCrrYaYjfGxawSw93dWTUlenCVTymJo8meBlFgIQ70ar4rUbzl6GX\nMYvRdku072d1WpglNHXkjKPkXQgngFDrh2sGKtNB/cEtJcAPRO8OiCgPFqRtMiNM\nc8VdPfPdZuHEIZsJ/aUM38EnqHi9YnVDQik2xxDe3wPghOhqjxUM6eLC9jrjI+7i\naIaEygUdyst9qVg8e2FGQlwAeS2Eh8ygCxn+bBlT5OyV59jSzbYfbhtF2qnWHtZy\nkL7KOOwhIfGs7O9SoR2ZVpTEQ4HthNzainIe/6iCR5HGrao/T8dygweXFYRv+k5A\nPQIDAQAB\n-----END PUBLIC KEY-----\n"

    [public_key] = :public_key.pem_decode(public_key_pem)

    public_key =
      public_key
      |> :public_key.pem_entry_decode()

    conn = %{
      req_headers: [
        {"host", "localtesting.pleroma.lol"},
        {"connection", "close"},
        {"content-length", "2316"},
        {"user-agent", "http.rb/2.2.2 (Mastodon/2.1.0.rc3; +http://mastodon.example.org/)"},
        {"date", "Sun, 10 Dec 2017 14:23:49 GMT"},
        {"digest", "SHA-256=x/bHADMW8qRrq2NdPb5P9fl0lYpKXXpe5h5maCIL0nM="},
        {"content-type", "application/activity+json"},
        {"(request-target)", "post /users/demiurge/inbox"},
        {"signature",
         "keyId=\"http://mastodon.example.org/users/admin#main-key\",algorithm=\"rsa-sha256\",headers=\"(request-target) user-agent host date digest content-type\",signature=\"i0FQvr51sj9BoWAKydySUAO1RDxZmNY6g7M62IA7VesbRSdFZZj9/fZapLp6YSuvxUF0h80ZcBEq9GzUDY3Chi9lx6yjpUAS2eKb+Am/hY3aswhnAfYd6FmIdEHzsMrpdKIRqO+rpQ2tR05LwiGEHJPGS0p528NvyVxrxMT5H5yZS5RnxY5X2HmTKEgKYYcvujdv7JWvsfH88xeRS7Jlq5aDZkmXvqoR4wFyfgnwJMPLel8P/BUbn8BcXglH/cunR0LUP7sflTxEz+Rv5qg+9yB8zgBsB4C0233WpcJxjeD6Dkq0EcoJObBR56F8dcb7NQtUDu7x6xxzcgSd7dHm5w==\""}
      ]
    }

    assert HTTPSignatures.validate_conn(conn, public_key)
  end

  test "it validates a conn and fetches the key" do
    conn = %{
      params: %{"actor" => "http://mastodon.example.org/users/admin"},
      req_headers: [
        {"host", "localtesting.pleroma.lol"},
        {"x-forwarded-for", "127.0.0.1"},
        {"connection", "close"},
        {"content-length", "2307"},
        {"user-agent", "http.rb/2.2.2 (Mastodon/2.1.0.rc3; +http://mastodon.example.org/)"},
        {"date", "Sun, 11 Feb 2018 17:12:01 GMT"},
        {"digest", "SHA-256=UXsAnMtR9c7mi1FOf6HRMtPgGI1yi2e9nqB/j4rZ99I="},
        {"content-type", "application/activity+json"},
        {"signature",
         "keyId=\"http://mastodon.example.org/users/admin#main-key\",algorithm=\"rsa-sha256\",headers=\"(request-target) user-agent host date digest content-type\",signature=\"qXKqpQXUpC3d9bZi2ioEeAqP8nRMD021CzH1h6/w+LRk4Hj31ARJHDwQM+QwHltwaLDUepshMfz2WHSXAoLmzWtvv7xRwY+mRqe+NGk1GhxVZ/LSrO/Vp7rYfDpfdVtkn36LU7/Bzwxvvaa4ZWYltbFsRBL0oUrqsfmJFswNCQIG01BB52BAhGSCORHKtQyzo1IZHdxl8y80pzp/+FOK2SmHkqWkP9QbaU1qTZzckL01+7M5btMW48xs9zurEqC2sM5gdWMQSZyL6isTV5tmkTZrY8gUFPBJQZgihK44v3qgfWojYaOwM8ATpiv7NG8wKN/IX7clDLRMA8xqKRCOKw==\""},
        {"(request-target)", "post /users/demiurge/inbox"}
      ]
    }

    assert HTTPSignatures.validate_conn(conn)
  end

  test "validate this" do
    conn = %{
      params: %{"actor" => "https://niu.moe/users/rye"},
      req_headers: [
        {"x-forwarded-for", "149.202.73.191"},
        {"host", "testing.pleroma.lol"},
        {"x-cluster-client-ip", "149.202.73.191"},
        {"connection", "upgrade"},
        {"content-length", "2396"},
        {"user-agent", "http.rb/3.0.0 (Mastodon/2.2.0; +https://niu.moe/)"},
        {"date", "Sun, 18 Feb 2018 20:31:51 GMT"},
        {"digest", "SHA-256=dzH+vLyhxxALoe9RJdMl4hbEV9bGAZnSfddHQzeidTU="},
        {"content-type", "application/activity+json"},
        {"signature",
         "keyId=\"https://niu.moe/users/rye#main-key\",algorithm=\"rsa-sha256\",headers=\"(request-target) user-agent host date digest content-type\",signature=\"wtxDg4kIpW7nsnUcVJhBk6SgJeDZOocr8yjsnpDRqE52lR47SH6X7G16r7L1AUJdlnbfx7oqcvomoIJoHB3ghP6kRnZW6MyTMZ2jPoi3g0iC5RDqv6oAmDSO14iw6U+cqZbb3P/odS5LkbThF0UNXcfenVNfsKosIJycFjhNQc54IPCDXYq/7SArEKJp8XwEgzmiC2MdxlkVIUSTQYfjM4EG533cwlZocw1mw72e5mm/owTa80BUZAr0OOuhoWARJV9btMb02ZyAF6SCSoGPTA37wHyfM1Dk88NHf7Z0Aov/Fl65dpRM+XyoxdkpkrhDfH9qAx4iuV2VEWddQDiXHA==\""},
        {"(request-target)", "post /inbox"}
      ]
    }

    assert HTTPSignatures.validate_conn(conn)
  end

  test "validate this too" do
    conn = %{
      params: %{"actor" => "https://niu.moe/users/rye"},
      req_headers: [
        {"x-forwarded-for", "149.202.73.191"},
        {"host", "testing.pleroma.lol"},
        {"x-cluster-client-ip", "149.202.73.191"},
        {"connection", "upgrade"},
        {"content-length", "2342"},
        {"user-agent", "http.rb/3.0.0 (Mastodon/2.2.0; +https://niu.moe/)"},
        {"date", "Sun, 18 Feb 2018 21:44:46 GMT"},
        {"digest", "SHA-256=vS8uDOJlyAu78cF3k5EzrvaU9iilHCX3chP37gs5sS8="},
        {"content-type", "application/activity+json"},
        {"signature",
         "keyId=\"https://niu.moe/users/rye#main-key\",algorithm=\"rsa-sha256\",headers=\"(request-target) user-agent host date digest content-type\",signature=\"IN6fHD8pLiDEf35dOaRHzJKc1wBYh3/Yq0ItaNGxUSbJTd2xMjigZbcsVKzvgYYjglDDN+disGNeD+OBKwMqkXWaWe/lyMc9wHvCH5NMhpn/A7qGLY8yToSt4vh8ytSkZKO6B97yC+Nvy6Fz/yMbvKtFycIvSXCq417cMmY6f/aG+rtMUlTbKO5gXzC7SUgGJCtBPCh1xZzu5/w0pdqdjO46ePNeR6JyJSLLV4hfo3+p2n7SRraxM4ePVCUZqhwS9LPt3Zdhy3ut+IXCZgMVIZggQFM+zXLtcXY5HgFCsFQr5WQDu+YkhWciNWtKFnWfAsnsg5sC330lZ/0Z8Z91yA==\""},
        {"(request-target)", "post /inbox"}
      ]
    }

    assert HTTPSignatures.validate_conn(conn)
  end

  test "it generates a signature" do
    user = insert(:user)
    assert HTTPSignatures.sign(user, %{host: "mastodon.example.org"}) =~ "keyId=\""
  end

  test "this too" do
    conn = %{
      params: %{"actor" => "https://mst3k.interlinked.me/users/luciferMysticus"},
      req_headers: [
        {"host", "soc.canned-death.us"},
        {"user-agent", "http.rb/3.0.0 (Mastodon/2.2.0; +https://mst3k.interlinked.me/)"},
        {"date", "Sun, 11 Mar 2018 12:19:36 GMT"},
        {"digest", "SHA-256=V7Hl6qDK2m8WzNsjzNYSBISi9VoIXLFlyjF/a5o1SOc="},
        {"content-type", "application/activity+json"},
        {"signature",
         "keyId=\"https://mst3k.interlinked.me/users/luciferMysticus#main-key\",algorithm=\"rsa-sha256\",headers=\"(request-target) user-agent host date digest content-type\",signature=\"CTYdK5a6lYMxzmqjLOpvRRASoxo2Rqib2VrAvbR5HaTn80kiImj15pCpAyx8IZp53s0Fn/y8MjCTzp+absw8kxx0k2sQAXYs2iy6xhdDUe7iGzz+XLAEqLyZIZfecynaU2nb3Z2XnFDjhGjR1vj/JP7wiXpwp6o1dpDZj+KT2vxHtXuB9585V+sOHLwSB1cGDbAgTy0jx/2az2EGIKK2zkw1KJuAZm0DDMSZalp/30P8dl3qz7DV2EHdDNfaVtrs5BfbDOZ7t1hCcASllzAzgVGFl0BsrkzBfRMeUMRucr111ZG+c0BNOEtJYOHSyZsSSdNknElggCJekONYMYk5ZA==\""},
        {"x-forwarded-for", "2607:5300:203:2899::31:1337"},
        {"x-forwarded-host", "soc.canned-death.us"},
        {"x-forwarded-server", "soc.canned-death.us"},
        {"connection", "Keep-Alive"},
        {"content-length", "2006"},
        {"(request-target)", "post /inbox"}
      ]
    }

    assert HTTPSignatures.validate_conn(conn)
  end
end
