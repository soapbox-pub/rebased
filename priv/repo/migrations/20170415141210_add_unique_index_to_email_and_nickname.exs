defmodule Pleroma.Repo.Migrations.AddUniqueIndexToEmailAndNickname do
  use Ecto.Migration

  def change do
    create_if_not_exists(unique_index(:users, [:email]))
    create_if_not_exists(unique_index(:users, [:nickname]))
  end
end
