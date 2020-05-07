defmodule Pleroma.Repo.Migrations.AddMultiFactorAuthenticationSettingsToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:multi_factor_authentication_settings, :map, default: %{})
    end
  end
end
