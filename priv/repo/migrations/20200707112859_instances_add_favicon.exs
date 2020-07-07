defmodule Pleroma.Repo.Migrations.InstancesAddFavicon do
  use Ecto.Migration

  def change do
    alter table(:instances) do
      add(:favicon, :string)
      add(:favicon_updated_at, :naive_datetime)
    end
  end
end
