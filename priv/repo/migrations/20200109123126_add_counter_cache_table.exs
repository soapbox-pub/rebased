defmodule Pleroma.Repo.Migrations.AddCounterCacheTable do
  use Ecto.Migration

  def up do
    create_if_not_exists table(:counter_cache) do
      add(:name, :string, null: false)
      add(:count, :bigint, null: false, default: 0)
    end

    create_if_not_exists(unique_index(:counter_cache, [:name]))

    """
    CREATE OR REPLACE FUNCTION update_status_visibility_counter_cache()
    RETURNS TRIGGER AS
    $$
      DECLARE
      BEGIN
      IF TG_OP = 'INSERT' THEN
          IF NEW.data->>'type' = 'Create' THEN
            EXECUTE 'INSERT INTO counter_cache (name, count) VALUES (''status_visibility_' || activity_visibility(NEW.actor, NEW.recipients, NEW.data) || ''', 1) ON CONFLICT (name) DO UPDATE SET count = counter_cache.count + 1';
          END IF;
          RETURN NEW;
      ELSIF TG_OP = 'UPDATE' THEN
          IF (NEW.data->>'type' = 'Create') and (OLD.data->>'type' = 'Create') and activity_visibility(NEW.actor, NEW.recipients, NEW.data) != activity_visibility(OLD.actor, OLD.recipients, OLD.data) THEN
             EXECUTE 'INSERT INTO counter_cache (name, count) VALUES (''status_visibility_' || activity_visibility(NEW.actor, NEW.recipients, NEW.data) || ''', 1) ON CONFLICT (name) DO UPDATE SET count = counter_cache.count + 1';
             EXECUTE 'update counter_cache SET count = counter_cache.count - 1 where count > 0 and name = ''status_visibility_' || activity_visibility(OLD.actor, OLD.recipients, OLD.data) || ''';';
          END IF;
          RETURN NEW;
      ELSIF TG_OP = 'DELETE' THEN
          IF OLD.data->>'type' = 'Create' THEN
            EXECUTE 'update counter_cache SET count = counter_cache.count - 1 where count > 0 and name = ''status_visibility_' || activity_visibility(OLD.actor, OLD.recipients, OLD.data) || ''';';
          END IF;
          RETURN OLD;
      END IF;
      END;
    $$
    LANGUAGE 'plpgsql';
    """
    |> execute()

    """
    CREATE TRIGGER status_visibility_counter_cache_trigger BEFORE INSERT OR UPDATE of recipients, data OR DELETE ON activities
    FOR EACH ROW
    EXECUTE PROCEDURE update_status_visibility_counter_cache();
    """
    |> execute()
  end

  def down do
    execute("drop trigger if exists status_visibility_counter_cache_trigger on activities")
    execute("drop function if exists update_status_visibility_counter_cache()")
    drop_if_exists(unique_index(:counter_cache, [:name]))
    drop_if_exists(table(:counter_cache))
  end
end
