defmodule Pleroma.Repo.Migrations.EnsureBioIsString do
  use Ecto.Migration

  def change do
    execute("update users set bio = '' where bio is null", "")
  end
end
