# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy do
  @moduledoc "Preloads any attachments in the MediaProxy cache by prefetching them"
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  alias Pleroma.HTTP
  alias Pleroma.Web.MediaProxy

  require Logger

  @impl true
  def history_awareness, do: :auto

  defp prefetch(url) do
    # Fetching only proxiable resources
    if MediaProxy.enabled?() and MediaProxy.url_proxiable?(url) do
      # If preview proxy is enabled, it'll also hit media proxy (so we're caching both requests)
      prefetch_url = MediaProxy.preview_url(url)

      Logger.debug("Prefetching #{inspect(url)} as #{inspect(prefetch_url)}")

      fetch(prefetch_url)
    end
  end

  defp fetch(url) do
    http_client_opts = Pleroma.Config.get([:media_proxy, :proxy_opts, :http], pool: :media)
    HTTP.get(url, [], http_client_opts)
  end

  defp preload(%{"object" => %{"attachment" => attachments}} = _activity) do
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
  def filter(%{"type" => type, "object" => %{"attachment" => attachments} = _object} = activity)
      when type in ["Create", "Update"] and is_list(attachments) and length(attachments) > 0 do
    preload(activity)

    {:ok, activity}
  end

  @impl true
  def filter(activity), do: {:ok, activity}

  @impl true
  def describe, do: {:ok, %{}}
end
