defmodule Pleroma.Repo.Migrations.UpdateActivityVisibilityAgain do
  use Ecto.Migration
  @disable_ddl_transaction true

  def up do
    definition = """
    create or replace function activity_visibility(actor varchar, recipients varchar[], data jsonb) returns varchar as $$
    DECLARE
      fa varchar;
      public varchar := 'https://www.w3.org/ns/activitystreams#Public';
    BEGIN
      SELECT COALESCE(users.follower_address, '') into fa from public.users where users.ap_id = actor;

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
    $$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE SECURITY DEFINER;
    """

    execute(definition)
  end

  def down do
  end
end
