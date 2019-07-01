defmodule Pleroma.Repo.Migrations.AddGroupKeyToConfig do
  use Ecto.Migration

  def change do
    alter table("config") do
      add(:group, :string)
    end

    drop_if_exists(unique_index("config", :key))
    create_if_not_exists(unique_index("config", [:group, :key]))
  end
end
