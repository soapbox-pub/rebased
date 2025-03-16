# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.TrailingFormatPlug do
  @moduledoc """
  This plug is adapted from [`TrailingFormatPlug`](https://github.com/mschae/trailing_format_plug/blob/master/lib/trailing_format_plug.ex).
  Ideally we would just do this in the router, but TrailingFormatPlug needs to be called before Plug.Parsers."
  """

  @behaviour Plug
  @paths [
    "/api/statusnet",
    "/api/statuses",
    "/api/qvitter",
    "/api/search",
    "/api/account",
    "/api/friends",
    "/api/mutes",
    "/api/media",
    "/api/favorites",
    "/api/blocks",
    "/api/friendships",
    "/api/users",
    "/users",
    "/nodeinfo",
    "/api/help",
    "/api/externalprofile",
    "/notice",
    "/api/pleroma/emoji",
    "/api/oauth_tokens"
  ]

  def init(opts) do
    opts
  end

  for path <- @paths do
    def call(%{request_path: unquote(path) <> _} = conn, opts) do
      path = conn.path_info |> List.last() |> String.split(".") |> Enum.reverse()

      supported_formats = Keyword.get(opts, :supported_formats, nil)

      case path do
        [_] ->
          conn

        [format | fragments] ->
          if supported_formats == nil || format in supported_formats do
            new_path = fragments |> Enum.reverse() |> Enum.join(".")
            path_fragments = List.replace_at(conn.path_info, -1, new_path)

            params =
              Plug.Conn.fetch_query_params(conn).params
              |> update_params(new_path, format)
              |> Map.put("_format", format)

            %{
              conn
              | path_info: path_fragments,
                query_params: params,
                params: params
            }
          else
            conn
          end
      end
    end
  end

  def call(conn, _opts), do: conn

  defp update_params(params, new_path, format) do
    wildcard = Enum.find(params, fn {_, v} -> v == "#{new_path}.#{format}" end)

    case wildcard do
      {key, _} ->
        Map.put(params, key, new_path)

      _ ->
        params
    end
  end
end
