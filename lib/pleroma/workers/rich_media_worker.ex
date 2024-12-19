# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.RichMediaWorker do
  alias Pleroma.Config
  alias Pleroma.Web.RichMedia.Backfill
  alias Pleroma.Web.RichMedia.Card

  use Oban.Worker, queue: :background, max_attempts: 3, unique: [period: :infinity]

  @impl true
  def perform(%Job{args: %{"op" => "expire", "url" => url} = _args}) do
    Card.delete(url)
  end

  def perform(%Job{args: %{"op" => "backfill", "url" => _url} = args}) do
    case Backfill.run(args) do
      :ok ->
        :ok

      {:error, type}
      when type in [:invalid_metadata, :body_too_large, :content_type, :validate, :get, :head] ->
        {:cancel, type}

      error ->
        {:error, error}
    end
  end

  # There is timeout value enforced by Tesla.Middleware.Timeout
  # which can be found in the RichMedia.Helpers module to allow us to detect
  # a slow/infinite data stream and insert a negative cache entry for the URL
  # We pad it by 2 seconds to be certain a slow connection is detected and we
  # can inject a negative cache entry for the URL
  @impl true
  def timeout(_job) do
    Config.get!([:rich_media, :timeout]) + :timer.seconds(2)
  end
end
