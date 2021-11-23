defmodule Pleroma.Repo.Migrations.ChangeHashtagsNameToText do
  use Ecto.Migration

  def up do
    alter table(:hashtags) do
      modify(:name, :text)
    end
  end

  def down do
    alter table(:hashtags) do
      modify(:name, :citext)
    end
  end
end
