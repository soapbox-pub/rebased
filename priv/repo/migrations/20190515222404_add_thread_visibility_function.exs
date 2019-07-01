defmodule Pleroma.Repo.Migrations.AddThreadVisibilityFunction do
  use Ecto.Migration
  @disable_ddl_transaction true

  def up do
    statement = """
    CREATE OR REPLACE FUNCTION thread_visibility(actor varchar, activity_id varchar) RETURNS boolean AS $$
    DECLARE
      public varchar := 'https://www.w3.org/ns/activitystreams#Public';
      child objects%ROWTYPE;
      activity activities%ROWTYPE;
      actor_user users%ROWTYPE;
      author_fa varchar;
      valid_recipients varchar[];
    BEGIN
      --- Fetch our actor.
      SELECT * INTO actor_user FROM users WHERE users.ap_id = actor;

      --- Fetch our initial activity.
      SELECT * INTO activity FROM activities WHERE activities.data->>'id' = activity_id;

      LOOP
        --- Ensure that we have an activity before continuing.
        --- If we don't, the thread is not satisfiable.
        IF activity IS NULL THEN
          RETURN false;
        END IF;

        --- We only care about Create activities.
        IF activity.data->>'type' != 'Create' THEN
          RETURN true;
        END IF;

        --- Normalize the child object into child.
        SELECT * INTO child FROM objects
        INNER JOIN activities ON COALESCE(activities.data->'object'->>'id', activities.data->>'object') = objects.data->>'id'
        WHERE COALESCE(activity.data->'object'->>'id', activity.data->>'object') = objects.data->>'id';

        --- Fetch the author's AS2 following collection.
        SELECT COALESCE(users.follower_address, '') INTO author_fa FROM users WHERE users.ap_id = activity.actor;

        --- Prepare valid recipients array.
        valid_recipients := ARRAY[actor, public];
        IF ARRAY[author_fa] && actor_user.following THEN
          valid_recipients := valid_recipients || author_fa;
        END IF;

        --- Check visibility.
        IF NOT valid_recipients && activity.recipients THEN
          --- activity not visible, break out of the loop
          RETURN false;
        END IF;

        --- If there's a parent, load it and do this all over again.
        IF (child.data->'inReplyTo' IS NOT NULL) AND (child.data->'inReplyTo' != 'null'::jsonb) THEN
          SELECT * INTO activity FROM activities
          INNER JOIN objects ON COALESCE(activities.data->'object'->>'id', activities.data->>'object') = objects.data->>'id'
          WHERE child.data->>'inReplyTo' = objects.data->>'id';
        ELSE
          RETURN true;
        END IF;
      END LOOP;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """

    execute(statement)
  end

  def down do
    execute("drop function if exists thread_visibility(actor varchar, activity_id varchar)")
  end
end
