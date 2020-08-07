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
