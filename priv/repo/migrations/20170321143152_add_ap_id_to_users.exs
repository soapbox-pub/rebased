defmodule Pleroma.Repo.Migrations.AddApIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:ap_id, :string)
    end
  end
end
