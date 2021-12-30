defmodule Pleroma.Repo.Migrations.UserRelationshipsTargetIdRelationshipTypeIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:user_relationships, [:target_id, :relationship_type]))
  end
end
