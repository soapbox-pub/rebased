defmodule Pleroma.Repo.Migrations.ResolveActivityObjectConflicts do
  @moduledoc """
  Find objects with a conflicting activity ID, and update them.
  This should only happen on servers that existed before "20181218172826_users_and_activities_flake_id".
  """
  use Ecto.Migration

  alias Pleroma.Object
  alias Pleroma.MigrationHelper.ObjectId
  alias Pleroma.Repo

  import Ecto.Query

  def up do
    # Lock relevant tables
    execute("LOCK TABLE objects")
    execute("LOCK TABLE chat_message_references")
    execute("LOCK TABLE deliveries")
    execute("LOCK TABLE hashtags_objects")

    activity_conflict_query()
    |> Repo.stream()
    |> Stream.each(&update_object!/1)
    |> Stream.run()
  end

  # Get only objects with a conflicting activity ID.
  defp activity_conflict_query() do
    join(Object, :inner, [o], a in "activities", on: a.id == o.id)
  end

  # Update the object and its relations with a newly-generated ID.
  defp update_object!(object) do
    new_id = ObjectId.flake_from_time(object.inserted_at)
    {:ok, %Object{}} = ObjectId.change_id(object, new_id)
  end

  def down do
    :ok
  end
end
