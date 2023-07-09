# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Fallback.RedirectController do
  use Pleroma.Web, :controller

  require Logger

  alias Pleroma.User
  alias Pleroma.Web.Metadata
  alias Pleroma.Web.Preload

  def api_not_implemented(conn, _params) do
    conn
    |> put_status(404)
    |> json(%{error: "Not implemented"})
  end

  def redirector(conn, params, code \\ 200) do
    redirector_with_ssr(conn, params, [:title, :favicon], code)
  end

  def redirector_with_meta(conn, %{"maybe_nickname_or_id" => maybe_nickname_or_id} = params) do
    with %User{} = user <- User.get_cached_by_nickname_or_id(maybe_nickname_or_id) do
      redirector_with_meta(conn, %{user: user})
    else
      nil ->
        redirector(conn, params)
    end
  end

  def redirector_with_meta(conn, params) do
    redirector_with_ssr(conn, params, [:tags, :preload, :title, :favicon])
  end

  def redirector_with_preload(conn, %{"path" => ["pleroma", "admin"]}) do
    redirect(conn, to: "/pleroma/admin/")
  end

  def redirector_with_preload(conn, params) do
    redirector_with_ssr(conn, params, [:preload, :title, :favicon])
  end

  defp redirector_with_ssr(conn, params, keys, code \\ 200) do
    {:ok, index_content} = File.read(index_file_path())

    meta = compose_meta(conn, params, keys)

    response =
      index_content
      |> String.replace("<!--server-generated-meta-->", Enum.join(meta))

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(code, response)
  end

  def registration_page(conn, params) do
    redirector(conn, params)
  end

  def empty(conn, _params) do
    conn
    |> put_status(204)
    |> text("")
  end

  defp index_file_path do
    Pleroma.Web.Plugs.InstanceStatic.file_path("index.html")
  end

  defp compose_meta(conn, params, attrs) when is_list(attrs) do
    Enum.map(attrs, fn attr ->
      build_meta(attr, {conn, params})
    end)
  end

  defp build_meta(:tags, {conn, params}) do
    try do
      Metadata.build_tags(params)
    rescue
      e ->
        Logger.error(
          "Metadata rendering for #{conn.request_path} failed.\n" <>
            Exception.format(:error, e, __STACKTRACE__)
        )

        ""
    end
  end

  defp build_meta(:preload, {conn, params}) do
    try do
      Preload.build_tags(conn, params)
    rescue
      e ->
        Logger.error(
          "Preloading for #{conn.request_path} failed.\n" <>
            Exception.format(:error, e, __STACKTRACE__)
        )

        ""
    end
  end

  defp build_meta(:title, _) do
    "<title>#{Pleroma.Config.get([:instance, :name])}</title>"
  end

  defp build_meta(:favicon, _) do
    "<link rel=\"icon\" href=\"#{Pleroma.Config.get([:instance, :favicon])}\">"
  end
end
