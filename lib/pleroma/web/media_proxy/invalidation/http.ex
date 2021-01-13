# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy.Invalidation.Http do
  @moduledoc false
  @behaviour Pleroma.Web.MediaProxy.Invalidation

  require Logger

  @impl Pleroma.Web.MediaProxy.Invalidation
  def purge(urls, opts \\ []) do
    method = Keyword.get(opts, :method, :purge)
    headers = Keyword.get(opts, :headers, [])
    options = Keyword.get(opts, :options, [])

    Logger.debug("Running cache purge: #{inspect(urls)}")

    Enum.each(urls, fn url ->
      with {:error, error} <- do_purge(method, url, headers, options) do
        Logger.error("Error while cache purge: url - #{url}, error: #{inspect(error)}")
      end
    end)

    {:ok, urls}
  end

  defp do_purge(method, url, headers, options) do
    case Pleroma.HTTP.request(method, url, "", headers, options) do
      {:ok, %{status: status} = env} when 400 <= status and status < 500 ->
        {:error, env}

      {:error, _} = error ->
        error

      _ ->
        {:ok, "success"}
    end
  end
end
