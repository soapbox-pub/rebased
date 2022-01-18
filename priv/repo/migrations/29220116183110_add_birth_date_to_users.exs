defmodule Pleroma.Repo.Migrations.AddBirthDateToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists(:birth_date, :date)
      add_if_not_exists(:hide_birth_date, :boolean, default: false, null: false)
    end
  end
end
