# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Cron.HashtagsCleanupWorker do
  @moduledoc """
  The worker to clean up unused hashtags_objects and hashtags.
  """

  use Oban.Worker, queue: "hashtags_cleanup"

  alias Pleroma.Repo

  require Logger

  @hashtags_objects_query """
  DELETE FROM hashtags_objects WHERE object_id IN
    (SELECT DISTINCT objects.id FROM objects
      JOIN hashtags_objects ON hashtags_objects.object_id = objects.id LEFT JOIN activities
        ON COALESCE(activities.data->'object'->>'id', activities.data->>'object') =
          (objects.data->>'id')
        AND activities.data->>'type' = 'Create'
      WHERE activities.id IS NULL);
  """

  @hashtags_query """
  DELETE FROM hashtags WHERE id IN
    (SELECT hashtags.id FROM hashtags
      LEFT OUTER JOIN hashtags_objects
        ON hashtags_objects.hashtag_id = hashtags.id
      WHERE hashtags_objects.hashtag_id IS NULL AND hashtags.inserted_at < $1);
  """

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Cleaning up unused `hashtags_objects` records...")

    {:ok, %{num_rows: hashtags_objects_count}} =
      Repo.query(@hashtags_objects_query, [], timeout: :infinity)

    Logger.info("Deleted #{hashtags_objects_count} unused `hashtags_objects` records.")

    Logger.info("Cleaning up unused `hashtags` records...")

    # Note: ignoring recently created hashtags since references are added after hashtag is created
    {:ok, %{num_rows: hashtags_count}} =
      Repo.query(@hashtags_query, [NaiveDateTime.add(NaiveDateTime.utc_now(), -3600 * 24)],
        timeout: :infinity
      )

    Logger.info("Deleted #{hashtags_count} unused `hashtags` records.")

    Logger.info("HashtagsCleanupWorker complete.")

    :ok
  end
end
