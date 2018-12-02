defmodule Pleroma.Repo.Migrations.AddUUIDExtension do
  use Ecto.Migration

  def change do
    execute("create extension if not exists \"uuid-ossp\"")
  end
end
