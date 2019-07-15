defmodule Pleroma.Repo.Migrations.FixInfoIds do
  use Ecto.Migration

  def up do
    execute(
      "update users set info = jsonb_set(info, '{id}', to_jsonb(uuid_generate_v4())) where info->'id' is null;"
    )
  end

  def down, do: :ok
end
