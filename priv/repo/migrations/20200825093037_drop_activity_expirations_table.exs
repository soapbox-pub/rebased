defmodule Pleroma.Repo.Migrations.DropActivityExpirationsTable do
  use Ecto.Migration

  def change do
    drop(table("activity_expirations"))
  end
end
