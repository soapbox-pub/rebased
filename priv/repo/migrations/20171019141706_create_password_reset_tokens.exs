defmodule Pleroma.Repo.Migrations.CreatePasswordResetTokens do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:password_reset_tokens) do
      add(:token, :string)
      add(:user_id, references(:users))
      add(:used, :boolean, default: false)

      timestamps()
    end
  end
end
