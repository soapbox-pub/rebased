defmodule Pleroma.Repo.Migrations.UsersAddLastRefreshedAt do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:last_refreshed_at, :naive_datetime_usec)
    end
  end
end
