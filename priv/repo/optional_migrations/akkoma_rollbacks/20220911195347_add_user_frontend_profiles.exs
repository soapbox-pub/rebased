# Adapted from Akkoma
# https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/priv/repo/migrations/20220911195347_add_user_frontend_profiles.exs

defmodule Pleroma.Repo.Migrations.AddUserFrontendProfiles do
  use Ecto.Migration

  def up, do: :ok

  def down do
    drop_if_exists(table("user_frontend_setting_profiles"))
    drop_if_exists(index(:user_frontend_setting_profiles, [:user_id, :frontend_name]))

    drop_if_exists(
      unique_index(:user_frontend_setting_profiles, [:user_id, :frontend_name, :profile_name])
    )
  end
end
