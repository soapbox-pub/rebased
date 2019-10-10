defmodule Pleroma.Repo.Migrations.AddVisibilityFunction do
  use Ecto.Migration
  @disable_ddl_transaction true

  def up do
    definition = """
    create or replace function activity_visibility(actor varchar, recipients varchar[], data jsonb) returns varchar as $$
    DECLARE
      fa varchar;
      public varchar := 'https://www.w3.org/ns/activitystreams#Public';
    BEGIN
      SELECT COALESCE(users.follower_address, '') into fa from users where users.ap_id = actor;

      IF data->'to' ? public THEN
        RETURN 'public';
      ELSIF data->'cc' ? public THEN
        RETURN 'unlisted';
      ELSIF ARRAY[fa] && recipients THEN
        RETURN 'private';
      ELSIF not(ARRAY[fa, public] && recipients) THEN
        RETURN 'direct';
      ELSE
        RETURN 'unknown';
      END IF;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """

    execute(definition)

    create(
      index(:activities, ["activity_visibility(actor, recipients, data)"],
        name: :activities_visibility_index,
        concurrently: true
      )
    )
  end

  def down do
    drop_if_exists(
      index(:activities, ["activity_visibility(actor, recipients, data)"],
        name: :activities_visibility_index
      )
    )

    execute(
      "drop function if exists activity_visibility(actor varchar, recipients varchar[], data jsonb)"
    )
  end
end
