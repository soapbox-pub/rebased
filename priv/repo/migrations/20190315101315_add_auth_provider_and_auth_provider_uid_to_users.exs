defmodule Pleroma.Repo.Migrations.AddAuthProviderAndAuthProviderUidToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :auth_provider, :string
      add :auth_provider_uid, :string
    end

    create unique_index(:users, [:auth_provider, :auth_provider_uid])
  end
end
