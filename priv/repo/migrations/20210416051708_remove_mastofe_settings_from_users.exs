defmodule Pleroma.Repo.Migrations.RemoveMastofeSettingsFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove_if_exists(:mastofe_settings, :map)
    end
  end
end
