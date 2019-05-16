# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Database do
  alias Mix.Tasks.Pleroma.Common
  alias Pleroma.Conversation
  require Logger
  use Mix.Task

  @shortdoc "A collection of database related tasks"
  @moduledoc """
   A collection of database related tasks

   ## Replace embedded objects with their references

   Replaces embedded objects with references to them in the `objects` table. Only needs to be ran once. The reason why this is not a migration is because it could significantly increase the database size after being ran, however after this `VACUUM FULL` will be able to reclaim about 20% (really depends on what is in the database, your mileage may vary) of the db size before the migration.

       mix pleroma.database remove_embedded_objects

    Options:
    - `--vacuum` - run `VACUUM FULL` after the embedded objects are replaced with their references

  ## Create a conversation for all existing DMs. Can be safely re-run.

      mix pleroma.database bump_all_conversations

  """
  def run(["remove_embedded_objects" | args]) do
    {options, [], []} =
      OptionParser.parse(
        args,
        strict: [
          vacuum: :boolean
        ]
      )

    Common.start_pleroma()
    Logger.info("Removing embedded objects")

    Pleroma.Repo.query!(
      "update activities set data = jsonb_set(data, '{object}'::text[], data->'object'->'id') where data->'object'->>'id' is not null;",
      [],
      timeout: :infinity
    )

    if Keyword.get(options, :vacuum) do
      Logger.info("Runnning VACUUM FULL")

      Pleroma.Repo.query!(
        "vacuum full;",
        [],
        timeout: :infinity
      )
    end
  end

  def run(["bump_all_conversations"]) do
    Common.start_pleroma()
    Conversation.bump_for_all_activities()
  end
end
