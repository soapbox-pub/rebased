# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddAssociatedObjectIdFunction do
  use Ecto.Migration

  def up do
    statement = """
    CREATE OR REPLACE FUNCTION associated_object_id(data jsonb) RETURNS varchar AS $$
    DECLARE
      object_data jsonb;
    BEGIN
      IF jsonb_typeof(data->'object') = 'array' THEN
        object_data := data->'object'->0;
      ELSE
        object_data := data->'object';
      END IF;

      IF jsonb_typeof(object_data->'id') = 'string' THEN
        RETURN object_data->>'id';
      ELSIF jsonb_typeof(object_data) = 'string' THEN
        RETURN object_data#>>'{}';
      ELSE
        RETURN NULL;
      END IF;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """

    execute(statement)
  end

  def down do
    execute("DROP FUNCTION IF EXISTS associated_object_id(data jsonb)")
  end
end
