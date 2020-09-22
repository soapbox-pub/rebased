defmodule Pleroma.Repo.Migrations.BioSetNotNull do
  use Ecto.Migration

  def change do
    execute(
      "alter table users alter column bio set not null",
      "alter table users alter column bio drop not null"
    )
  end
end
