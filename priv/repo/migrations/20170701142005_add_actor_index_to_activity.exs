defmodule Pleroma.Repo.Migrations.AddActorIndexToActivity do
  use Ecto.Migration

  def change do
    create index(:activities, ["(data->>'actor')", "inserted_at desc"], name: :activities_actor_index)
  end
end
