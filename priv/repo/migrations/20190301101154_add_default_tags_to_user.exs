defmodule Pleroma.Repo.Migrations.AddDefaultTagsToUser do
  use Ecto.Migration

  def up do
    execute("UPDATE users SET tags = array[]::varchar[] where tags IS NULL")
  end

  def down, do: :noop
end
