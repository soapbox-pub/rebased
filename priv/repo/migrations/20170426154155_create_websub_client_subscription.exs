defmodule Pleroma.Repo.Migrations.CreateWebsubClientSubscription do
  use Ecto.Migration

  def change do
    create table(:websub_client_subscriptions) do
      add :topic, :string
      add :secret, :string
      add :valid_until, :naive_datetime_usec
      add :state, :string
      add :subscribers, :map

      timestamps()
    end
  end
end
