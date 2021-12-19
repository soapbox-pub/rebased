defmodule Pleroma.Repo.Migrations.AddSuggestions do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:is_suggested, :boolean, default: false, null: false)
    end

    create_if_not_exists(index(:users, [:is_suggested]))
  end
end
