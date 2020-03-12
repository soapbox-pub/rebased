# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.MappedSignatureToIdentityPlug do
  alias Pleroma.Signature
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Utils

  import Plug.Conn
  require Logger

  def init(options), do: options

  defp key_id_from_conn(conn) do
    with %{"keyId" => key_id} <- HTTPSignatures.signature_for_conn(conn) do
      Signature.key_id_to_actor_id(key_id)
    else
      _ ->
        nil
    end
  end

  defp user_from_key_id(conn) do
    with key_actor_id when is_binary(key_actor_id) <- key_id_from_conn(conn),
         {:ok, %User{} = user} <- User.get_or_fetch_by_ap_id(key_actor_id) do
      user
    else
      _ ->
        nil
    end
  end

  def call(%{assigns: %{user: _}} = conn, _opts), do: conn

  # if this has payload make sure it is signed by the same actor that made it
  def call(%{assigns: %{valid_signature: true}, params: %{"actor" => actor}} = conn, _opts) do
    with actor_id <- Utils.get_ap_id(actor),
         {:user, %User{} = user} <- {:user, user_from_key_id(conn)},
         {:user_match, true} <- {:user_match, user.ap_id == actor_id} do
      assign(conn, :user, user)
    else
      {:user_match, false} ->
        Logger.debug("Failed to map identity from signature (payload actor mismatch)")
        Logger.debug("key_id=#{key_id_from_conn(conn)}, actor=#{actor}")
        assign(conn, :valid_signature, false)

      # remove me once testsuite uses mapped capabilities instead of what we do now
      {:user, nil} ->
        Logger.debug("Failed to map identity from signature (lookup failure)")
        Logger.debug("key_id=#{key_id_from_conn(conn)}, actor=#{actor}")
        conn
    end
  end

  # no payload, probably a signed fetch
  def call(%{assigns: %{valid_signature: true}} = conn, _opts) do
    with %User{} = user <- user_from_key_id(conn) do
      assign(conn, :user, user)
    else
      _ ->
        Logger.debug("Failed to map identity from signature (no payload actor mismatch)")
        Logger.debug("key_id=#{key_id_from_conn(conn)}")
        assign(conn, :valid_signature, false)
    end
  end

  # no signature at all
  def call(conn, _opts), do: conn
end
