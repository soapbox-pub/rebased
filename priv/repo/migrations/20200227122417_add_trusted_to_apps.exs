defmodule Pleroma.Repo.Migrations.AddTrustedToApps do
  use Ecto.Migration

  def change do
    alter table(:apps) do
      add(:trusted, :boolean, default: false)
    end
  end
end
