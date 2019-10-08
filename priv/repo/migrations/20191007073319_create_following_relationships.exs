defmodule Pleroma.Repo.Migrations.CreateFollowingRelationships do
  use Ecto.Migration

  # had to disable these to be able to restore `following` index concurrently
  # https://hexdocs.pm/ecto_sql/Ecto.Migration.html#index/3-adding-dropping-indexes-concurrently

  def change do
    create_if_not_exists table(:following_relationships) do
      add(:follower_id, references(:users, type: :uuid, on_delete: :delete_all), null: false)
      add(:following_id, references(:users, type: :uuid, on_delete: :delete_all), null: false)
      add(:state, :string, null: false)

      timestamps()
    end

    create_if_not_exists(index(:following_relationships, :follower_id))
    create_if_not_exists(unique_index(:following_relationships, [:follower_id, :following_id]))
  end
end
