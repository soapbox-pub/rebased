defmodule Pleroma.Repo.Migrations.ChangePushSubscriptionsVarchar do
  use Ecto.Migration

  def up do
    alter table(:push_subscriptions) do
      modify(:endpoint, :varchar)
    end
  end

  def down do
    alter table(:push_subscriptions) do
      modify(:endpoint, :string)
    end
  end
end
