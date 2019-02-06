# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

# https://tools.ietf.org/html/draft-cavage-http-signatures-08
defmodule Pleroma.Web.HTTPSignatures do
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.{ActivityPub, Utils}

  require Logger

  def split_signature(sig) do
    default = %{"headers" => "date"}

    sig =
      sig
      |> String.trim()
      |> String.split(",")
      |> Enum.reduce(default, fn part, acc ->
        [key | rest] = String.split(part, "=")
        value = Enum.join(rest, "=")
        Map.put(acc, key, String.trim(value, "\""))
      end)

    Map.put(sig, "headers", String.split(sig["headers"], ~r/\s/))
  end

  def validate(headers, signature, public_key) do
    sigstring = build_signing_string(headers, signature["headers"])
    Logger.debug("Signature: #{signature["signature"]}")
    Logger.debug("Sigstring: #{sigstring}")
    {:ok, sig} = Base.decode64(signature["signature"])
    :public_key.verify(sigstring, :sha256, sig, public_key)
  end

  def validate_conn(conn) do
    # TODO: How to get the right key and see if it is actually valid for that request.
    # For now, fetch the key for the actor.
    with actor_id <- Utils.get_ap_id(conn.params["actor"]),
         {:ok, public_key} <- User.get_public_key_for_ap_id(actor_id) do
      if validate_conn(conn, public_key) do
        true
      else
        Logger.debug("Could not validate, re-fetching user and trying one more time")
        # Fetch user anew and try one more time
        with actor_id <- Utils.get_ap_id(conn.params["actor"]),
             {:ok, _user} <- ActivityPub.make_user_from_ap_id(actor_id),
             {:ok, public_key} <- User.get_public_key_for_ap_id(actor_id) do
          validate_conn(conn, public_key)
        end
      end
    else
      _e ->
        Logger.debug("Could not public key!")
        false
    end
  end

  def validate_conn(conn, public_key) do
    headers = Enum.into(conn.req_headers, %{})
    signature = split_signature(headers["signature"])
    validate(headers, signature, public_key)
  end

  def build_signing_string(headers, used_headers) do
    used_headers
    |> Enum.map(fn header -> "#{header}: #{headers[header]}" end)
    |> Enum.join("\n")
  end

  def sign(user, headers) do
    with {:ok, %{info: %{keys: keys}}} <- Pleroma.Web.WebFinger.ensure_keys_present(user),
         {:ok, private_key, _} = Pleroma.Web.Salmon.keys_from_pem(keys) do
      sigstring = build_signing_string(headers, Map.keys(headers))

      signature =
        :public_key.sign(sigstring, :sha256, private_key)
        |> Base.encode64()

      [
        keyId: user.ap_id <> "#main-key",
        algorithm: "rsa-sha256",
        headers: Map.keys(headers) |> Enum.join(" "),
        signature: signature
      ]
      |> Enum.map(fn {k, v} -> "#{k}=\"#{v}\"" end)
      |> Enum.join(",")
    end
  end
end
