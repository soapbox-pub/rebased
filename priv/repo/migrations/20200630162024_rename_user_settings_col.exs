defmodule Pleroma.Repo.Migrations.RenameUserSettingsCol do
  use Ecto.Migration

  def up do
    rename(table(:users), :settings, to: :mastofe_settings)
  end

  def down do
    rename(table(:users), :mastofe_settings, to: :settings)
  end
end
