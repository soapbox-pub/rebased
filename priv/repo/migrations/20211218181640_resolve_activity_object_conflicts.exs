defmodule Pleroma.Repo.Migrations.ResolveActivityObjectConflicts do
  @moduledoc """
  Find objects with a conflicting activity ID, and update them.
  """
  use Ecto.Migration

  alias Pleroma.Object
  alias Pleroma.Migrators.Support.ObjectId
  alias Pleroma.Repo

  def up do
    Object
    |> join(:inner, [o], a in "activities", on: a.id == o.id)
    |> Repo.stream()
    |> Stream.each(fn object ->
      # TODO
    end)
  end

  def down do
    :ok
  end
end
