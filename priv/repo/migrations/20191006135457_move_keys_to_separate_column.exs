defmodule Pleroma.Repo.Migrations.MoveKeysToSeparateColumn do
  use Ecto.Migration

  def change do
    execute(
      "update users set keys = info->>'keys' where local",
      "update users set info = jsonb_set(info, '{keys}'::text[], to_jsonb(keys)) where local"
    )
  end
end
