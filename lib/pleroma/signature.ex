# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Signature do
  @behaviour HTTPSignatures.Adapter

  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.Salmon
  alias Pleroma.Web.WebFinger

  def fetch_public_key(conn) do
    with actor_id <- Utils.get_ap_id(conn.params["actor"]),
         {:ok, public_key} <- User.get_public_key_for_ap_id(actor_id) do
      {:ok, public_key}
    else
      e ->
        {:error, e}
    end
  end

  def refetch_public_key(conn) do
    with actor_id <- Utils.get_ap_id(conn.params["actor"]),
         {:ok, _user} <- ActivityPub.make_user_from_ap_id(actor_id),
         {:ok, public_key} <- User.get_public_key_for_ap_id(actor_id) do
      {:ok, public_key}
    else
      e ->
        {:error, e}
    end
  end

  def sign(%User{} = user, headers) do
    with {:ok, %{info: %{keys: keys}}} <- WebFinger.ensure_keys_present(user),
         {:ok, private_key, _} <- Salmon.keys_from_pem(keys) do
      HTTPSignatures.sign(private_key, user.ap_id <> "#main-key", headers)
    end
  end
end
