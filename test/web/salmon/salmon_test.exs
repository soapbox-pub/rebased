defmodule Pleroma.Web.Salmon.SalmonTest do
  use Pleroma.DataCase
  alias Pleroma.Web.Salmon

  @magickey "RSA.pu0s-halox4tu7wmES1FVSx6u-4wc0YrUFXcqWXZG4-27UmbCOpMQftRCldNRfyA-qLbz-eqiwQhh-1EwUvjsD4cYbAHNGHwTvDOyx5AKthQUP44ykPv7kjKGh3DWKySJvcs9tlUG87hlo7AvnMo9pwRS_Zz2CacQ-MKaXyDepk=.AQAB"

  @wrong_magickey "RSA.pu0s-halox4tu7wmES1FVSx6u-4wc0YrUFXcqWXZG4-27UmbCOpMQftRCldNRfyA-qLbz-eqiwQhh-1EwUvjsD4cYbAHNGHwTvDOyx5AKthQUP44ykPv7kjKGh3DWKySJvcs9tlUG87hlo7AvnMo9pwRS_Zz2CacQ-MKaXyDepk=.AQAA"

  test "decodes a salmon" do
    {:ok, salmon} = File.read("test/fixtures/salmon.xml")
    {:ok, doc} = Salmon.decode_and_validate(@magickey, salmon)
    assert Regex.match?(~r/xml/, doc)
  end

  test "errors on wrong magic key" do
    {:ok, salmon} = File.read("test/fixtures/salmon.xml")
    assert Salmon.decode_and_validate(@wrong_magickey, salmon) == :error
  end

  test "generates an RSA private key pem" do
    {:ok, key} = Salmon.generate_rsa_pem
    assert is_binary(key)
    assert Regex.match?(~r/RSA/, key)
  end

  test "it encodes a magic key from a public key" do
    key = Salmon.decode_key(@magickey)
    magic_key = Salmon.encode_key(key)

    assert @magickey == magic_key
  end

  test "returns a public and private key from a pem" do
    pem = File.read!("test/fixtures/private_key.pem")
    {:ok, private, public} = Salmon.keys_from_pem(pem)

    assert elem(private, 0) == :RSAPrivateKey
    assert elem(public, 0) == :RSAPublicKey
  end

  test "encodes an xml payload with a private key" do
    doc = File.read!("test/fixtures/incoming_note_activity.xml")
    pem = File.read!("test/fixtures/private_key.pem")
    {:ok, private, public} = Salmon.keys_from_pem(pem)

    # Let's try a roundtrip.
    {:ok, salmon} = Salmon.encode(private, doc)
    {:ok, decoded_doc} = Salmon.decode_and_validate(Salmon.encode_key(public), salmon)

    assert doc == decoded_doc
  end
end
