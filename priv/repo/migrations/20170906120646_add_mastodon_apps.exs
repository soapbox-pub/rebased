defmodule Pleroma.Repo.Migrations.AddMastodonApps do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:apps) do
      add(:client_name, :string)
      add(:redirect_uris, :string)
      add(:scopes, :string)
      add(:website, :string)
      add(:client_id, :string)
      add(:client_secret, :string)

      timestamps()
    end
  end
end
