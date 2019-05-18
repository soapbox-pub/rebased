defmodule Pleroma.Repo.Migrations.AddFtsIndexToObjectsTwo do
  use Ecto.Migration

  def up do
    execute("create extension if not exists rum")
    drop_if_exists index(:objects, ["(to_tsvector('english', data->>'content'))"], using: :gin, name: :objects_fts)
    alter table(:objects) do
      add(:fts_content, :tsvector)
    end

    execute("CREATE FUNCTION objects_fts_update() RETURNS trigger AS $$
    begin
      new.fts_content := to_tsvector('english', new.data->>'content');
      return new;
    end
    $$ LANGUAGE plpgsql")
    execute("create index objects_fts on objects using RUM (fts_content rum_tsvector_addon_ops, inserted_at) with (attach = 'inserted_at', to = 'fts_content');")

    execute("CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE ON objects
    FOR EACH ROW EXECUTE PROCEDURE objects_fts_update()")

    execute("UPDATE objects SET updated_at = NOW()")
  end

  def down do
    execute "drop index objects_fts"
    execute "drop trigger tsvectorupdate on objects"
    execute "drop function objects_fts_update()"
    alter table(:objects) do
      remove(:fts_content, :tsvector)
    end
    create index(:objects, ["(to_tsvector('english', data->>'content'))"], using: :gin, name: :objects_fts)
  end
end
