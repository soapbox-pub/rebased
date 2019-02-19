defmodule Pleroma.Repo.Migrations.CreateUserMutes do
  use Ecto.Migration

  def change do
    execute "UPDATE users SET info = jsonb_set(info, '{mutes}', '[]'::jsonb);"
  end
end
