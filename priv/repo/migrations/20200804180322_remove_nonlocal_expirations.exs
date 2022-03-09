# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RemoveNonlocalExpirations do
  use Ecto.Migration

  def up do
    statement = """
    DELETE FROM
      activity_expirations A USING activities B
    WHERE
      A.activity_id = B.id
      AND B.local = false;
    """

    execute(statement)
  end

  def down do
    :ok
  end
end
