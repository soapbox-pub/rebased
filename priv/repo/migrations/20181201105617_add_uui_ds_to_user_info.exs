defmodule Pleroma.Repo.Migrations.AddUUIDsToUserInfo do
  use Ecto.Migration

  def change do
    execute("update users set info = jsonb_set(info, '{\"id\"}', to_jsonb(uuid_generate_v4()))")
  end
end
