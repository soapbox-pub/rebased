# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.RichMediaWorker do
  alias Pleroma.Web.RichMedia.Backfill
  alias Pleroma.Web.RichMedia.Card

  use Oban.Worker, queue: :background, max_attempts: 3, unique: [period: 300]

  @impl Oban.Worker
  def perform(%Job{args: %{"op" => "expire", "url" => url} = _args}) do
    Card.delete(url)
  end

  def perform(%Job{args: %{"op" => "backfill", "url" => _url} = args}) do
    case Backfill.run(args) do
      :ok ->
        :ok

      {:error, type}
      when type in [:invalid_metadata, :body_too_large, :content_type, :validate] ->
        {:cancel, type}

      {:error, type}
      when type in [:get, :head] ->
        {:error, type}

      error ->
        {:error, error}
    end
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.seconds(5)
end
