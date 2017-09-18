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

  test "it contructs a signing string" do
    expected = "date: Thu, 05 Jan 2014 21:31:40 GMT\ncontent-length: 18"
    assert expected == HTTPSignatures.build_signing_string(@headers, ["date", "content-length"])
  end
end
