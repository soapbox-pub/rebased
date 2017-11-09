defmodule Pleroma.Repo.Migrations.AddActorToActivity do
  use Ecto.Migration

  alias Pleroma.{Repo, Activity}

  @disable_ddl_transaction true

  def up do
    alter table(:activities) do
      add :actor, :string
    end

    max = Repo.aggregate(Activity, :max, :id)
    IO.puts("#{max} activities")
    chunks = 0..(round(max / 10_000))

    Enum.each(chunks, fn (i) ->
      min = i * 10_000
      max = min + 10_000
      IO.puts("Updating #{min}")
      execute """
        update activities set actor = data->>'actor' where id > #{min} and id <= #{max};
      """
    end)

    create index(:activities, [:actor, "id DESC NULLS LAST"], concurrently: true)
  end

  def down do
    drop index(:activities, [:actor, "id DESC NULLS LAST"])
    alter table(:activities) do
      remove :actor
    end
  end
end
