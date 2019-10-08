defmodule Pleroma.Repo.Migrations.ActuallyDropLocalIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:users, [:local]))
    drop_if_exists(index("activities", :local))
  end
end
