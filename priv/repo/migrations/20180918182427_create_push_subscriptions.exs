defmodule Pleroma.Repo.Migrations.CreatePushSubscriptions do
  use Ecto.Migration

  def change do
    create_if_not_exists table("push_subscriptions") do
      add(:user_id, references("users", on_delete: :delete_all))
      add(:token_id, references("oauth_tokens", on_delete: :delete_all))
      add(:endpoint, :string)
      add(:key_p256dh, :string)
      add(:key_auth, :string)
      add(:data, :map)

      timestamps()
    end

    create_if_not_exists(index("push_subscriptions", [:user_id, :token_id], unique: true))
  end
end
