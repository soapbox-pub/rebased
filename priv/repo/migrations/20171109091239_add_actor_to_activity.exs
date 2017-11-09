defmodule Pleroma.Repo.Migrations.AddActorToActivity do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    alter table(:activities) do
      add :actor, :string
    end

    execute """
      update activities set actor = data->>'actor';
    """

    create index(:activities, [:actor, "id DESC NULLS LAST"], concurrently: true)
  end

  def down do
    drop index(:activities, [:actor, "id DESC NULLS LAST"])
    alter table(:activities) do
      remove :actor
    end
  end
end
