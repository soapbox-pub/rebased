defmodule Pleroma.Repo.Migrations.AddRecipientsContainBlockedDomainsFunction do
  use Ecto.Migration
  @disable_ddl_transaction true

  def up do
    statement = """
    CREATE OR REPLACE FUNCTION recipients_contain_blocked_domains(recipients varchar[], blocked_domains varchar[]) RETURNS boolean AS $$
    DECLARE
      recipient_domain varchar;
      recipient varchar;
    BEGIN
      FOREACH recipient IN ARRAY recipients LOOP
        recipient_domain = split_part(recipient, '/', 3)::varchar;

        IF recipient_domain = ANY(blocked_domains) THEN
          RETURN TRUE;
        END IF;
      END LOOP;

      RETURN FALSE;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute(statement)
  end

  def down do
    execute(
      "drop function if exists recipients_contain_blocked_domains(recipients varchar[], blocked_domains varchar[])"
    )
  end
end
