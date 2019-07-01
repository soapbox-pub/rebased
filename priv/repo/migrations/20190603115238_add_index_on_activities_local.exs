defmodule Pleroma.Repo.Migrations.AddIndexOnActivitiesLocal do
  use Ecto.Migration

  def change do
    create_if_not_exists(index("activities", [:local]))
  end
end
