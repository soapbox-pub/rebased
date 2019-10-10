defmodule Pleroma.Repo.Migrations.AddIndexOnSubscribers do
  use Ecto.Migration

  @disable_ddl_transaction true
  def change do
    create(
      index(:users, ["(info->'subscribers')"],
        name: :users_subscribers_index,
        using: :gin,
        concurrently: true
      )
    )
  end
end
