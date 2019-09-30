defmodule Pleroma.Repo.Migrations.CreateModerationLog do
  use Ecto.Migration

  def change do
    create table(:moderation_log) do
      add(:data, :map)

      timestamps()
    end
  end
end
