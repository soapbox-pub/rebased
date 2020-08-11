defmodule Pleroma.Repo.Migrations.ApIdNotNull do
  use Ecto.Migration

  def up do
    alter table(:users) do
      modify(:ap_id, :string, null: false)
    end
  end

  def down do
    :ok
  end
end
