# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy do
  @moduledoc "Preloads any attachments in the MediaProxy cache by prefetching them"
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  alias Pleroma.HTTP
  alias Pleroma.Web.MediaProxy

  require Logger

  @adapter_options [
    pool: :media,
    recv_timeout: 10_000
  ]

  defp prefetch(url) do
    # Fetching only proxiable resources
    if MediaProxy.enabled?() and MediaProxy.url_proxiable?(url) do
      # If preview proxy is enabled, it'll also hit media proxy (so we're caching both requests)
      prefetch_url = MediaProxy.preview_url(url)

      Logger.debug("Prefetching #{inspect(url)} as #{inspect(prefetch_url)}")

      if Pleroma.Config.get(:env) == :test do
        fetch(prefetch_url)
      else
        ConcurrentLimiter.limit(__MODULE__, fn ->
          Task.start(fn -> fetch(prefetch_url) end)
        end)
      end
    end
  end

  defp fetch(url), do: HTTP.get(url, [], @adapter_options)

  defp preload(%{"object" => %{"attachment" => attachments}} = _message) do
    Enum.each(attachments, fn
      %{"url" => url} when is_list(url) ->
        url
        |> Enum.each(fn
          %{"href" => href} ->
            prefetch(href)

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
    preload(message)

    {:ok, message}
  end

  @impl true
  def filter(message), do: {:ok, message}

  @impl true
  def describe, do: {:ok, %{}}
end
