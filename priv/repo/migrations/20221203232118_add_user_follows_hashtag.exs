defmodule Pleroma.Repo.Migrations.AddUserFollowsHashtag do
  use Ecto.Migration

  def change do
    create table(:user_follows_hashtag) do
      add(:hashtag_id, references(:hashtags))
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
    end

    create(unique_index(:user_follows_hashtag, [:user_id, :hashtag_id]))

    create_if_not_exists(index(:user_follows_hashtag, [:hashtag_id]))
  end
end
