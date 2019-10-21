defmodule Pleroma.Repo.Migrations.CreateUserInviteTokens do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:user_invite_tokens) do
      add(:token, :string)
      add(:used, :boolean, default: false)

      timestamps()
    end
  end
end
