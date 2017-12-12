# https://tools.ietf.org/html/draft-cavage-http-signatures-08
defmodule Pleroma.Web.HTTPSignatures do
  alias Pleroma.User

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
    :public_key.verify(sigstring, :sha256, sig, public_key)
  end

  def validate_conn(conn) do
    # TODO: How to get the right key and see if it is actually valid for that request.
    # For now, fetch the key for the actor.
    with actor_id <- conn.params["actor"],
         {:ok, public_key} <- User.get_public_key_for_ap_id(actor_id) do
      validate_conn(conn, public_key)
    else
      _ -> false
    end
  end

  def validate_conn(conn, public_key) do
    headers = Enum.into(conn.req_headers, %{})
    signature = split_signature(headers["signature"])
    validate(headers, signature, public_key)
  end

  def build_signing_string(headers, used_headers) do
    used_headers
    |> Enum.map(fn (header) -> "#{header}: #{headers[header]}" end)
    |> Enum.join("\n")
  end
end
