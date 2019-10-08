defmodule Pleroma.Repo.Migrations.AddActorToActivity do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    alter table(:activities) do
      add(:actor, :string)
    end

    create(index(:activities, [:actor, "id DESC NULLS LAST"], concurrently: true))
  end

  def down do
    drop_if_exists(index(:activities, [:actor, "id DESC NULLS LAST"]))

    alter table(:activities) do
      remove(:actor)
    end
  end
end
