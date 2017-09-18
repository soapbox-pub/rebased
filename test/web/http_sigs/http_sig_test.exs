# http signatures
# Test data from https://tools.ietf.org/html/draft-cavage-http-signatures-08#appendix-C
defmodule Pleroma.Web.HTTPSignaturesTest do
  use Pleroma.DataCase
  alias Pleroma.Web.HTTPSignatures

  @private_key (hd(:public_key.pem_decode(File.read!("test/web/http_sigs/priv.key")))
    |> :public_key.pem_entry_decode())

  @public_key (hd(:public_key.pem_decode(File.read!("test/web/http_sigs/pub.key")))
    |> :public_key.pem_entry_decode())

  @headers %{
    "(request-target)" => "post /foo?param=value&pet=dog",
    "host" => "example.com",
    "date" => "Thu, 05 Jan 2014 21:31:40 GMT",
    "content-type" => "application/json",
    "digest" => "SHA-256=X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=",
    "content-length" => "18"
  }

  @body "{\"hello\": \"world\"}"

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
      "signature" => "jKyvPcxB4JbmYY4mByyBY7cZfNl4OW9HpFQlG7N4YcJPteKTu4MWCLyk+gIr0wDgqtLWf9NLpMAMimdfsH7FSWGfbMFSrsVTHNTk0rK3usrfFnti1dxsM4jl0kYJCKTGI/UWkqiaxwNiKqGcdlEDrTcUhhsFsOIo8VhddmZTZ8w=",
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
end
