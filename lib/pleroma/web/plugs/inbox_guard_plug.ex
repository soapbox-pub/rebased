# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.InboxGuardPlug do
  import Plug.Conn
  import Pleroma.Constants, only: [activity_types: 0, allowed_activity_types_from_strangers: 0]

  alias Pleroma.Config
  alias Pleroma.User

  def init(options) do
    options
  end

  def call(%{assigns: %{valid_signature: true}} = conn, _opts) do
    with {_, true} <- {:federating, Config.get!([:instance, :federating])} do
      conn
      |> filter_activity_types()
    else
      {:federating, false} ->
        conn
        |> json(403, "Not federating")
        |> halt()
    end
  end

  def call(conn, _opts) do
    with {_, true} <- {:federating, Config.get!([:instance, :federating])},
         conn = filter_activity_types(conn),
         {:known, true} <- {:known, known_actor?(conn)} do
      conn
    else
      {:federating, false} ->
        conn
        |> json(403, "Not federating")
        |> halt()

      {:known, false} ->
        conn
        |> filter_from_strangers()
    end
  end

  # Early rejection of unrecognized types
  defp filter_activity_types(%{body_params: %{"type" => type}} = conn) do
    with true <- type in activity_types() do
      conn
    else
      _ ->
        conn
        |> json(400, "Invalid activity type")
        |> halt()
    end
  end

  # If signature failed but we know this actor we should
  # accept it as we may only need to refetch their public key
  # during processing
  defp known_actor?(%{body_params: data}) do
    case Pleroma.Object.Containment.get_actor(data) |> User.get_cached_by_ap_id() do
      %User{} -> true
      _ -> false
    end
  end

  # Only permit a subset of activity types from strangers
  # or else it will add actors you've never interacted with
  # to the database
  defp filter_from_strangers(%{body_params: %{"type" => type}} = conn) do
    with true <- type in allowed_activity_types_from_strangers() do
      conn
    else
      _ ->
        conn
        |> json(400, "Invalid activity type for an unknown actor")
        |> halt()
    end
  end

  defp json(conn, status, resp) do
    json_resp = Jason.encode!(resp)

    conn
    |> put_resp_content_type("application/json")
    |> resp(status, json_resp)
    |> halt()
  end
end
