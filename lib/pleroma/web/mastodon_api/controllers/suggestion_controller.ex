# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SuggestionController do
  use Pleroma.Web, :controller

  require Logger

  alias Pleroma.Config
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.User
  alias Pleroma.Web.MediaProxy

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  plug(OAuthScopesPlug, %{scopes: ["read"]} when action == :index)

  plug(Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug)

  @doc "GET /api/v1/suggestions"
  def index(%{assigns: %{user: user}} = conn, _) do
    if Config.get([:suggestions, :enabled], false) do
      with {:ok, data} <- fetch_suggestions(user) do
        limit = Config.get([:suggestions, :limit], 23)

        data =
          data
          |> Enum.slice(0, limit)
          |> Enum.map(fn x ->
            x
            |> Map.put("id", fetch_suggestion_id(x))
            |> Map.put("avatar", MediaProxy.url(x["avatar"]))
            |> Map.put("avatar_static", MediaProxy.url(x["avatar_static"]))
          end)

        json(conn, data)
      end
    else
      json(conn, [])
    end
  end

  defp fetch_suggestions(user) do
    api = Config.get([:suggestions, :third_party_engine], "")
    timeout = Config.get([:suggestions, :timeout], 5000)
    host = Config.get([Pleroma.Web.Endpoint, :url, :host])

    url =
      api
      |> String.replace("{{host}}", host)
      |> String.replace("{{user}}", user.nickname)

    with {:ok, %{status: 200, body: body}} <-
           Pleroma.HTTP.get(url, [], adapter: [recv_timeout: timeout, pool: :default]) do
      Jason.decode(body)
    else
      e -> Logger.error("Could not retrieve suggestions at fetch #{url}, #{inspect(e)}")
    end
  end

  defp fetch_suggestion_id(attrs) do
    case User.get_or_fetch(attrs["acct"]) do
      {:ok, %User{id: id}} -> id
      _ -> 0
    end
  end
end
