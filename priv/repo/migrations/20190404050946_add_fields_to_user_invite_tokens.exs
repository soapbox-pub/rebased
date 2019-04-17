defmodule Pleroma.Repo.Migrations.AddFieldsToUserInviteTokens do
  use Ecto.Migration

  def change do
    alter table(:user_invite_tokens) do
      add(:expires_at, :date)
      add(:uses, :integer, default: 0)
      add(:max_use, :integer)
      add(:invite_type, :string, default: "one_time")
    end
  end
end
