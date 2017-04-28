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
end
