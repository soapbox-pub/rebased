# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Backfill do
  alias Pleroma.Web.RichMedia.Card
  alias Pleroma.Web.RichMedia.Parser
  alias Pleroma.Web.RichMedia.Parser.TTL
  alias Pleroma.Workers.RichMediaExpirationWorker

  require Logger

  @backfiller Pleroma.Config.get([__MODULE__, :provider], Pleroma.Web.RichMedia.Backfill.Task)
  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)
  @max_attempts 3
  @retry 5_000

  def start(%{url: url} = args) when is_binary(url) do
    url_hash = Card.url_to_hash(url)

    args =
      args
      |> Map.put(:attempt, 1)
      |> Map.put(:url_hash, url_hash)

    @backfiller.run(args)
  end

  def run(%{url: url, url_hash: url_hash, attempt: attempt} = args)
      when attempt <= @max_attempts do
    case Parser.parse(url) do
      {:ok, fields} ->
        {:ok, card} = Card.create(url, fields)

        maybe_schedule_expiration(url, fields)

        if Map.has_key?(args, :activity_id) do
          stream_update(args)
        end

        warm_cache(url_hash, card)

      {:error, {:invalid_metadata, fields}} ->
        Logger.debug("Rich media incomplete or invalid metadata for #{url}: #{inspect(fields)}")
        negative_cache(url_hash)

      {:error, :body_too_large} ->
        Logger.error("Rich media error for #{url}: :body_too_large")
        negative_cache(url_hash)

      {:error, {:content_type, type}} ->
        Logger.debug("Rich media error for #{url}: :content_type is #{type}")
        negative_cache(url_hash)

      e ->
        Logger.debug("Rich media error for #{url}: #{inspect(e)}")

        :timer.sleep(@retry * attempt)

        run(%{args | attempt: attempt + 1})
    end
  end

  def run(%{url: url, url_hash: url_hash}) do
    Logger.debug("Rich media failure for #{url}")

    negative_cache(url_hash, :timer.minutes(15))
  end

  defp maybe_schedule_expiration(url, fields) do
    case TTL.process(fields, url) do
      {:ok, ttl} when is_number(ttl) ->
        timestamp = DateTime.from_unix!(ttl)

        RichMediaExpirationWorker.new(%{"url" => url}, scheduled_at: timestamp)
        |> Oban.insert()

      _ ->
        :ok
    end
  end

  defp stream_update(%{activity_id: activity_id}) do
    Pleroma.Activity.get_by_id(activity_id)
    |> Pleroma.Activity.normalize()
    |> Pleroma.Web.ActivityPub.ActivityPub.stream_out()
  end

  defp warm_cache(key, val), do: @cachex.put(:rich_media_cache, key, val)
  defp negative_cache(key, ttl \\ nil), do: @cachex.put(:rich_media_cache, key, nil, ttl: ttl)
end

defmodule Pleroma.Web.RichMedia.Backfill.Task do
  alias Pleroma.Web.RichMedia.Backfill

  def run(args) do
    Task.Supervisor.start_child(Pleroma.TaskSupervisor, Backfill, :run, [args],
      name: {:global, {:rich_media, args.url_hash}}
    )
  end
end
