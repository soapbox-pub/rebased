defmodule Pleroma.Repo.Migrations.CreateThreadMutes do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:thread_mutes) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:context, :string)
    end

    create_if_not_exists(unique_index(:thread_mutes, [:user_id, :context], name: :unique_index))
  end
end
