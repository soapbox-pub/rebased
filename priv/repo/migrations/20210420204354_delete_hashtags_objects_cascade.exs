defmodule Pleroma.Repo.Migrations.DeleteHashtagsObjectsCascade do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE hashtags_objects DROP CONSTRAINT hashtags_objects_object_id_fkey")

    alter table(:hashtags_objects) do
      modify(:object_id, references(:objects, on_delete: :delete_all))
    end
  end

  def down do
    execute("ALTER TABLE hashtags_objects DROP CONSTRAINT hashtags_objects_object_id_fkey")

    alter table(:hashtags_objects) do
      modify(:object_id, references(:objects, on_delete: :nothing))
    end
  end
end
