defmodule Pleroma.Repo.Migrations.CreateOAuthAuthorizations do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:oauth_authorizations) do
      add(:app_id, references(:apps))
      add(:user_id, references(:users))
      add(:token, :string)
      add(:valid_until, :naive_datetime_usec)
      add(:used, :boolean, default: false)

      timestamps()
    end
  end
end
