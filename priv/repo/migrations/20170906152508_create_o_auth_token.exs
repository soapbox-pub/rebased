defmodule Pleroma.Repo.Migrations.CreateOAuthToken do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:oauth_tokens) do
      add(:app_id, references(:apps))
      add(:user_id, references(:users))
      add(:token, :string)
      add(:refresh_token, :string)
      add(:valid_until, :naive_datetime_usec)

      timestamps()
    end
  end
end
