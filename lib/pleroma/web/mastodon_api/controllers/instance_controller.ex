# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.InstanceController do
  use Pleroma.Web, :controller

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(:skip_auth when action in [:show, :peers])

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.InstanceOperation

  @doc "GET /api/v1/instance"
  def show(conn, _params) do
    render(conn, "show.json")
  end

  @doc "GET /api/v2/instance"
  def show2(conn, _params) do
    render(conn, "show2.json")
  end

  @doc "GET /api/v1/instance/peers"
  def peers(conn, _params) do
    json(conn, Pleroma.Stats.get_peers())
  end

  @doc "GET /api/v1/instance/rules"
  def rules(conn, _params) do
    render(conn, "rules.json")
  end

  @doc "GET /api/v1/instance/privacy_policy"
  def privacy_policy(conn, _params) do
    with path when is_binary(path) <- Pleroma.Config.get([:instance, :privacy_policy]),
         path <- Pleroma.Web.Plugs.InstanceStatic.file_path(path),
         true <- File.exists?(path),
         {:ok, content} <- File.read(path),
         {:ok, %{mtime: updated_at}} <- File.stat(path),
         updated_at <- Timex.to_datetime(updated_at, "Etc/UTC") do
      json(conn, %{
        updated_at: updated_at,
        content: content
      })
    else
      _ -> {:error, :not_found}
    end
  end
end
