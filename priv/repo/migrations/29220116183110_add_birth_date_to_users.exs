defmodule Pleroma.Repo.Migrations.AddBirthDateToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists(:birthday, :date)
      add_if_not_exists(:show_birthday, :boolean, default: false, null: false)
    end
  end
end
