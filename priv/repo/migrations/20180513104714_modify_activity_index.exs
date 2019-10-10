defmodule Pleroma.Repo.Migrations.ModifyActivityIndex do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    create(index(:activities, ["id desc nulls last", "local"], concurrently: true))
    drop_if_exists(index(:activities, ["id desc nulls last"]))
  end
end
