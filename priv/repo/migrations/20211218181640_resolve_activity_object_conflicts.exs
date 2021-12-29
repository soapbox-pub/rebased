defmodule Pleroma.Repo.Migrations.ResolveActivityObjectConflicts do
  @moduledoc """
  Find objects with a conflicting activity ID, and update them.
  This should only happen on servers that existed before "20181218172826_users_and_activities_flake_id".
  """
  use Ecto.Migration

  alias Pleroma.Object
  alias Pleroma.Migrators.Support.ObjectId
  alias Pleroma.Repo

  import Ecto.Query

  def up do
    Object
    |> join(:inner, [o], a in "activities", on: a.id == o.id)
    |> Repo.stream()
    |> Stream.each(fn object ->
      # TODO
      :error
    end)
  end

  def down do
    :ok
  end
end
