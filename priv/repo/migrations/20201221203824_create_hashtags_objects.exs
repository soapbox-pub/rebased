defmodule Pleroma.Repo.Migrations.CreateHashtagsObjects do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:hashtags_objects, primary_key: false) do
      add(:hashtag_id, references(:hashtags), null: false, primary_key: true)
      add(:object_id, references(:objects), null: false, primary_key: true)
    end

    create_if_not_exists(unique_index(:hashtags_objects, [:hashtag_id, :object_id]))
    create_if_not_exists(index(:hashtags_objects, [:object_id]))
  end
end
