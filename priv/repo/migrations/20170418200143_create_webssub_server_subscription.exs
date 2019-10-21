defmodule Pleroma.Repo.Migrations.CreateWebsubServerSubscription do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:websub_server_subscriptions) do
      add(:topic, :string)
      add(:callback, :string)
      add(:secret, :string)
      add(:valid_until, :naive_datetime)
      add(:state, :string)

      timestamps()
    end
  end
end
