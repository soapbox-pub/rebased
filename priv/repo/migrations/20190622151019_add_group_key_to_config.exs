defmodule Pleroma.Repo.Migrations.AddGroupKeyToConfig do
  use Ecto.Migration

  def change do
    alter table("config") do
      add(:group, :string)
    end

    drop(unique_index("config", :key))
    create(unique_index("config", [:group, :key]))
  end
end
