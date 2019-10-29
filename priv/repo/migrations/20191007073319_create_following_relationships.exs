defmodule Pleroma.Repo.Migrations.CreateFollowingRelationships do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:following_relationships) do
      add(:follower_id, references(:users, type: :uuid, on_delete: :delete_all), null: false)
      add(:following_id, references(:users, type: :uuid, on_delete: :delete_all), null: false)
      add(:state, :string, null: false)

      timestamps()
    end

    create_if_not_exists(index(:following_relationships, :follower_id))
    create_if_not_exists(unique_index(:following_relationships, [:follower_id, :following_id]))

    execute(update_thread_visibility(), restore_thread_visibility())
  end

  # The only difference between the original version: `actor_user` replaced with `actor_user_following`
  def update_thread_visibility do
    """
    CREATE OR REPLACE FUNCTION thread_visibility(actor varchar, activity_id varchar) RETURNS boolean AS $$
    DECLARE
      public varchar := 'https://www.w3.org/ns/activitystreams#Public';
      child objects%ROWTYPE;
      activity activities%ROWTYPE;
      author_fa varchar;
      valid_recipients varchar[];
      actor_user_following varchar[];
    BEGIN
      --- Fetch actor following
      SELECT array_agg(following.follower_address) INTO actor_user_following FROM following_relationships
      JOIN users ON users.id = following_relationships.follower_id
      JOIN users AS following ON following.id = following_relationships.following_id
      WHERE users.ap_id = actor;

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
        IF ARRAY[author_fa] && actor_user_following THEN
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
  end

  # priv/repo/migrations/20190515222404_add_thread_visibility_function.exs
  def restore_thread_visibility do
    """
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
  end
end
