defmodule Pleroma.Repo.Migrations.AddIndexOnActivitiesLocal do
  use Ecto.Migration

  def change do
    create(index("activities", [:local]))
  end
end
