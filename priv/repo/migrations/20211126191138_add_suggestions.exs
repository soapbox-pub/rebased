defmodule Pleroma.Repo.Migrations.AddSuggestions do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:is_suggested, :boolean, default: false, null: false)
    end
  end
end
