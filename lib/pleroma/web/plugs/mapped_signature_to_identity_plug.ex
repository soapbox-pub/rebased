# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.MappedSignatureToIdentityPlug do
  alias Pleroma.Helpers.AuthHelper
  alias Pleroma.Signature
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Utils

  import Plug.Conn
  require Logger

  def init(options), do: options

  def call(%{assigns: %{user: %User{}}} = conn, _opts), do: conn

  # if this has payload make sure it is signed by the same actor that made it
  def call(%{assigns: %{valid_signature: true}, params: %{"actor" => actor}} = conn, _opts) do
    with actor_id <- Utils.get_ap_id(actor),
         {:user, %User{} = user} <- {:user, user_from_key_id(conn)},
         {:user_match, true} <- {:user_match, user.ap_id == actor_id} do
      conn
      |> assign(:user, user)
      |> AuthHelper.skip_oauth()
    else
      {:user_match, false} ->
        Logger.debug("Failed to map identity from signature (payload actor mismatch)")
        Logger.debug("key_id=#{inspect(key_id_from_conn(conn))}, actor=#{inspect(actor)}")
        assign(conn, :valid_signature, false)

      # remove me once testsuite uses mapped capabilities instead of what we do now
      {:user, nil} ->
        Logger.debug("Failed to map identity from signature (lookup failure)")
        Logger.debug("key_id=#{inspect(key_id_from_conn(conn))}, actor=#{actor}")
        conn
    end
  end

  # no payload, probably a signed fetch
  def call(%{assigns: %{valid_signature: true}} = conn, _opts) do
    with %User{} = user <- user_from_key_id(conn) do
      conn
      |> assign(:user, user)
      |> AuthHelper.skip_oauth()
    else
      _ ->
        Logger.debug("Failed to map identity from signature (no payload actor mismatch)")
        Logger.debug("key_id=#{inspect(key_id_from_conn(conn))}")
        assign(conn, :valid_signature, false)
    end
  end

  # no signature at all
  def call(conn, _opts), do: conn

  defp key_id_from_conn(conn) do
    with %{"keyId" => key_id} <- HTTPSignatures.signature_for_conn(conn),
         {:ok, ap_id} <- Signature.key_id_to_actor_id(key_id) do
      ap_id
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
end
