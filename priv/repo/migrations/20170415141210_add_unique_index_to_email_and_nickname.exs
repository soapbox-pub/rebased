defmodule Pleroma.Repo.Migrations.AddUniqueIndexToEmailAndNickname do
  use Ecto.Migration

  def change do
    create unique_index(:users, [:email])
    create unique_index(:users, [:nickname])
  end
end
