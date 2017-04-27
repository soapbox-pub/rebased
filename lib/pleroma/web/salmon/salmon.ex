defmodule Pleroma.Web.Salmon do
  use Bitwise

  def decode(salmon) do
    {doc, _rest} = :xmerl_scan.string(to_charlist(salmon))

    {:xmlObj, :string, data} = :xmerl_xpath.string('string(//me:data[1])', doc)
    {:xmlObj, :string, sig} = :xmerl_xpath.string('string(//me:sig[1])', doc)
    {:xmlObj, :string, alg} = :xmerl_xpath.string('string(//me:alg[1])', doc)
    {:xmlObj, :string, encoding} = :xmerl_xpath.string('string(//me:encoding[1])', doc)
    {:xmlObj, :string, type} = :xmerl_xpath.string('string(//me:data[1]/@type)', doc)

    {:ok, data} = Base.url_decode64(to_string(data), ignore: :whitespace)
    {:ok, sig} = Base.url_decode64(to_string(sig), ignore: :whitespace)
    alg = to_string(alg)
    encoding = to_string(encoding)
    type = to_string(type)

    [data, type, encoding, alg, sig]
  end

  def fetch_magic_key(salmon) do
    [data, _, _, _, _] = decode(salmon)
    {doc, _rest} = :xmerl_scan.string(to_charlist(data))
    {:xmlObj, :string, uri} = :xmerl_xpath.string('string(//author[1]/uri)', doc)

    uri = to_string(uri)
    base = URI.parse(uri).host

    # TODO: Find out if this endpoint is mandated by the standard.
    {:ok, response} = HTTPoison.get(base <> "/.well-known/webfinger", ["Accept": "application/xrd+xml"], [params: [resource: uri]])

    {doc, _rest} = :xmerl_scan.string(to_charlist(response.body))

    {:xmlObj, :string, magickey} = :xmerl_xpath.string('string(//Link[@rel="magic-public-key"]/@href)', doc)
    "data:application/magic-public-key," <> magickey = to_string(magickey)

    magickey
  end

  def decode_and_validate(magickey, salmon) do
    [data, type, encoding, alg, sig] = decode(salmon)

    signed_text = [data, type, encoding, alg]
    |> Enum.map(&Base.url_encode64/1)
    |> Enum.join(".")

    key = decode_key(magickey)

    verify = :public_key.verify(signed_text, :sha256, sig, key)

    if verify do
      {:ok, data}
    else
      :error
    end
  end

  defp decode_key("RSA." <> magickey) do
    make_integer = fn(bin) ->
      list = :erlang.binary_to_list(bin)
      Enum.reduce(list, 0, fn (el, acc) -> (acc <<< 8) ||| el end)
    end

    [modulus, exponent] = magickey
    |> String.split(".")
    |> Enum.map(&Base.url_decode64!/1)
    |> Enum.map(make_integer)

    {:RSAPublicKey, modulus, exponent}
  end
end
