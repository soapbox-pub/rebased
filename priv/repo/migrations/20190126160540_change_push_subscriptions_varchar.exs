defmodule Pleroma.Repo.Migrations.ChangePushSubscriptionsVarchar do
  use Ecto.Migration

  def change do
    alter table(:push_subscriptions) do
      modify(:endpoint, :varchar)
    end
  end
end
