# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Database do
  alias Mix.Tasks.Pleroma.Common
  alias Pleroma.Conversation
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
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

  ## Prune old objects from the database

      mix pleroma.database prune_objects

  ## Create a conversation for all existing DMs. Can be safely re-run.

      mix pleroma.database bump_all_conversations

  ## Remove duplicated items from following and update followers count for all users

      mix pleroma.database update_users_following_followers_counts
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

    Repo.query!(
      "update activities set data = jsonb_set(data, '{object}'::text[], data->'object'->'id') where data->'object'->>'id' is not null;",
      [],
      timeout: :infinity
    )

    if Keyword.get(options, :vacuum) do
      Logger.info("Runnning VACUUM FULL")

      Repo.query!(
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

  def run(["update_users_following_followers_counts"]) do
    Common.start_pleroma()

    users = Repo.all(User)
    Enum.each(users, &User.remove_duplicated_following/1)
    Enum.each(users, &User.update_follower_count/1)
  end

  def run(["prune_objects" | args]) do
    import Ecto.Query

    {options, [], []} =
      OptionParser.parse(
        args,
        strict: [
          vacuum: :boolean
        ]
      )

    Common.start_pleroma()

    deadline = Pleroma.Config.get([:instance, :remote_post_retention_days])

    Logger.info("Pruning objects older than #{deadline} days")

    time_deadline =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-(deadline * 86_400))

    public = "https://www.w3.org/ns/activitystreams#Public"

    from(o in Object,
      where: fragment("?->'to' \\? ? OR ?->'cc' \\? ?", o.data, ^public, o.data, ^public),
      where: o.inserted_at < ^time_deadline,
      where:
        fragment("split_part(?->>'actor', '/', 3) != ?", o.data, ^Pleroma.Web.Endpoint.host())
    )
    |> Repo.delete_all()

    if Keyword.get(options, :vacuum) do
      Logger.info("Runnning VACUUM FULL")

      Repo.query!(
        "vacuum full;",
        [],
        timeout: :infinity
      )
    end
  end
end
