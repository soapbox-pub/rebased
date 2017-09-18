# https://tools.ietf.org/html/draft-cavage-http-signatures-08
defmodule Pleroma.Web.HTTPSignatures do
  def split_signature(sig) do
    default = %{"headers" => "date"}

    sig = sig
    |> String.trim()
    |> String.split(",")
    |> Enum.reduce(default, fn(part, acc) ->
      [key | rest] = String.split(part, "=")
      value = Enum.join(rest, "=")
      Map.put(acc, key, String.trim(value, "\""))
    end)

    Map.put(sig, "headers", String.split(sig["headers"], ~r/\s/))
  end

  def validate(headers, signature, public_key) do
    sigstring = build_signing_string(headers, signature["headers"])
    {:ok, sig} = Base.decode64(signature["signature"])
    verify = :public_key.verify(sigstring, :sha256, sig, public_key)
  end

  def build_signing_string(headers, used_headers) do
    used_headers
    |> Enum.map(fn (header) -> "#{header}: #{headers[header]}" end)
    |> Enum.join("\n")
  end
end
