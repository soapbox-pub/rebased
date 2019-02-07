defmodule Pleroma.Repo.Migrations.CreateThreadMutes do
  use Ecto.Migration

  def change do
    create table(:thread_mutes) do
      add :user, references(:users, type: :uuid, on_delete: :delete_all)
      add :context, :string
    end
    
    create index(:thread_mutes, [:user])
  end
end
