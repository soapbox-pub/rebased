# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Signature do
  @behaviour HTTPSignatures.Adapter

  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Keys
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub

  def key_id_to_actor_id(key_id) do
    uri =
      URI.parse(key_id)
      |> Map.put(:fragment, nil)

    uri =
      if not is_nil(uri.path) and String.ends_with?(uri.path, "/publickey") do
        Map.put(uri, :path, String.replace(uri.path, "/publickey", ""))
      else
        uri
      end

    maybe_ap_id = URI.to_string(uri)

    case ObjectValidators.ObjectID.cast(maybe_ap_id) do
      {:ok, ap_id} ->
        {:ok, ap_id}

      _ ->
        case Pleroma.Web.WebFinger.finger(maybe_ap_id) do
          %{"ap_id" => ap_id} -> {:ok, ap_id}
          _ -> {:error, maybe_ap_id}
        end
    end
  end

  def fetch_public_key(conn) do
    with %{"keyId" => kid} <- HTTPSignatures.signature_for_conn(conn),
         {:ok, actor_id} <- key_id_to_actor_id(kid),
         {:ok, public_key} <- User.get_public_key_for_ap_id(actor_id) do
      {:ok, public_key}
    else
      e ->
        {:error, e}
    end
  end

  def refetch_public_key(conn) do
    with %{"keyId" => kid} <- HTTPSignatures.signature_for_conn(conn),
         {:ok, actor_id} <- key_id_to_actor_id(kid),
         {:ok, _user} <- ActivityPub.make_user_from_ap_id(actor_id),
         {:ok, public_key} <- User.get_public_key_for_ap_id(actor_id) do
      {:ok, public_key}
    else
      e ->
        {:error, e}
    end
  end

  def sign(%User{} = user, headers) do
    with {:ok, %{keys: keys}} <- User.ensure_keys_present(user),
         {:ok, private_key, _} <- Keys.keys_from_pem(keys) do
      HTTPSignatures.sign(private_key, user.ap_id <> "#main-key", headers)
    end
  end

  def signed_date, do: signed_date(NaiveDateTime.utc_now())

  def signed_date(%NaiveDateTime{} = date) do
    Timex.format!(date, "{WDshort}, {0D} {Mshort} {YYYY} {h24}:{m}:{s} GMT")
  end
end
