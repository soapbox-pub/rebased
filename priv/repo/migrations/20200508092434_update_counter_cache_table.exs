# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.UpdateCounterCacheTable do
  use Ecto.Migration

  @function_name "update_status_visibility_counter_cache"
  @trigger_name "status_visibility_counter_cache_trigger"

  def up do
    execute("drop trigger if exists #{@trigger_name} on activities")
    execute("drop function if exists #{@function_name}()")
    drop_if_exists(unique_index(:counter_cache, [:name]))
    drop_if_exists(table(:counter_cache))

    create_if_not_exists table(:counter_cache) do
      add(:instance, :string, null: false)
      add(:direct, :bigint, null: false, default: 0)
      add(:private, :bigint, null: false, default: 0)
      add(:unlisted, :bigint, null: false, default: 0)
      add(:public, :bigint, null: false, default: 0)
    end

    create_if_not_exists(unique_index(:counter_cache, [:instance]))

    """
    CREATE OR REPLACE FUNCTION #{@function_name}()
    RETURNS TRIGGER AS
    $$
      DECLARE
        hostname character varying(255);
        visibility_new character varying(64);
        visibility_old character varying(64);
        actor character varying(255);
      BEGIN
      IF TG_OP = 'DELETE' THEN
        actor := OLD.actor;
      ELSE
        actor := NEW.actor;
      END IF;
      hostname := split_part(actor, '/', 3);
      IF TG_OP = 'INSERT' THEN
        visibility_new := activity_visibility(NEW.actor, NEW.recipients, NEW.data);
        IF NEW.data->>'type' = 'Create'
            AND visibility_new IN ('public', 'unlisted', 'private', 'direct') THEN
          EXECUTE format('INSERT INTO "counter_cache" ("instance", %1$I) VALUES ($1, 1)
                          ON CONFLICT ("instance") DO
                          UPDATE SET %1$I = "counter_cache".%1$I + 1', visibility_new)
                          USING hostname;
        END IF;
        RETURN NEW;
      ELSIF TG_OP = 'UPDATE' THEN
        visibility_new := activity_visibility(NEW.actor, NEW.recipients, NEW.data);
        visibility_old := activity_visibility(OLD.actor, OLD.recipients, OLD.data);
        IF (NEW.data->>'type' = 'Create')
            AND (OLD.data->>'type' = 'Create')
            AND visibility_new != visibility_old
            AND visibility_new IN ('public', 'unlisted', 'private', 'direct') THEN
          EXECUTE format('UPDATE "counter_cache" SET
                          %1$I = greatest("counter_cache".%1$I - 1, 0),
                          %2$I = "counter_cache".%2$I + 1
                          WHERE "instance" = $1', visibility_old, visibility_new)
                          USING hostname;
        END IF;
        RETURN NEW;
      ELSIF TG_OP = 'DELETE' THEN
        IF OLD.data->>'type' = 'Create' THEN
          visibility_old := activity_visibility(OLD.actor, OLD.recipients, OLD.data);
          EXECUTE format('UPDATE "counter_cache" SET
                          %1$I = greatest("counter_cache".%1$I - 1, 0)
                          WHERE "instance" = $1', visibility_old)
                          USING hostname;
        END IF;
        RETURN OLD;
      END IF;
      END;
    $$
    LANGUAGE 'plpgsql';
    """
    |> execute()

    execute("DROP TRIGGER IF EXISTS #{@trigger_name} ON activities")

    """
    CREATE TRIGGER #{@trigger_name}
    BEFORE
      INSERT
      OR UPDATE of recipients, data
      OR DELETE
    ON activities
    FOR EACH ROW
      EXECUTE PROCEDURE #{@function_name}();
    """
    |> execute()
  end

  def down do
    execute("DROP TRIGGER IF EXISTS #{@trigger_name} ON activities")
    execute("DROP FUNCTION IF EXISTS #{@function_name}()")
    drop_if_exists(unique_index(:counter_cache, [:instance]))
    drop_if_exists(table(:counter_cache))

    create_if_not_exists table(:counter_cache) do
      add(:name, :string, null: false)
      add(:count, :bigint, null: false, default: 0)
    end

    create_if_not_exists(unique_index(:counter_cache, [:name]))

    """
    CREATE OR REPLACE FUNCTION #{@function_name}()
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
    CREATE TRIGGER #{@trigger_name} BEFORE INSERT OR UPDATE of recipients, data OR DELETE ON activities
    FOR EACH ROW
    EXECUTE PROCEDURE #{@function_name}();
    """
    |> execute()
  end
end
