defmodule Pleroma.Repo.Migrations.RevertCitextChange do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify(:uri, :text)
    end

    # create_if_not_exists(unique_index(:users, :uri))
  end
end
