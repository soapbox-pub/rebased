# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy do
  @moduledoc "Preloads any attachments in the MediaProxy cache by prefetching them"
  @behaviour Pleroma.Web.ActivityPub.MRF

  alias Pleroma.HTTP
  alias Pleroma.Web.MediaProxy
  alias Pleroma.Workers.BackgroundWorker

  require Logger

  @adapter_options [
    pool: :media,
    recv_timeout: 10_000
  ]

  def perform(:prefetch, url) do
    # Fetching only proxiable resources
    if MediaProxy.enabled?() and MediaProxy.url_proxiable?(url) do
      # If preview proxy is enabled, it'll also hit media proxy (so we're caching both requests)
      prefetch_url = MediaProxy.preview_url(url)

      Logger.debug("Prefetching #{inspect(url)} as #{inspect(prefetch_url)}")

      HTTP.get(prefetch_url, [], @adapter_options)
    end
  end

  def perform(:preload, %{"object" => %{"attachment" => attachments}} = _message) do
    Enum.each(attachments, fn
      %{"url" => url} when is_list(url) ->
        url
        |> Enum.each(fn
          %{"href" => href} ->
            BackgroundWorker.enqueue("media_proxy_prefetch", %{"url" => href})

          x ->
            Logger.debug("Unhandled attachment URL object #{inspect(x)}")
        end)

      x ->
        Logger.debug("Unhandled attachment #{inspect(x)}")
    end)
  end

  @impl true
  def filter(
        %{"type" => "Create", "object" => %{"attachment" => attachments} = _object} = message
      )
      when is_list(attachments) and length(attachments) > 0 do
    BackgroundWorker.enqueue("media_proxy_preload", %{"message" => message})

    {:ok, message}
  end

  @impl true
  def filter(message), do: {:ok, message}

  @impl true
  def describe, do: {:ok, %{}}
end
