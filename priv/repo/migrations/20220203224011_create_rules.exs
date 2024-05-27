defmodule Pleroma.Repo.Migrations.CreateRules do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:rules) do
      add(:priority, :integer, default: 0, null: false)
      add(:text, :text, null: false)

      timestamps()
    end
  end
end
