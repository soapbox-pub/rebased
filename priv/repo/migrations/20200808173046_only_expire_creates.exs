# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.OnlyExpireCreates do
  use Ecto.Migration

  def up do
    statement = """
    DELETE FROM
      activity_expirations a_exp USING activities a, objects o
    WHERE
      a_exp.activity_id = a.id AND (o.data->>'id') = COALESCE(a.data->'object'->>'id', a.data->>'object')
      AND (a.data->>'type' != 'Create' OR o.data->>'type' != 'Note');
    """

    execute(statement)
  end

  def down do
    :ok
  end
end
