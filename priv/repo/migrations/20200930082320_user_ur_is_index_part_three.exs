defmodule Pleroma.Repo.Migrations.UserURIsIndexPartThree do
  use Ecto.Migration

  def change do
    drop_if_exists(unique_index(:users, :uri))
    create_if_not_exists(index(:users, :uri))
  end
end
