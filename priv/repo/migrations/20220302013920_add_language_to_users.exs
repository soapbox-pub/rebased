defmodule Pleroma.Repo.Migrations.AddLanguageToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists(:language, :string)
    end
  end
end
