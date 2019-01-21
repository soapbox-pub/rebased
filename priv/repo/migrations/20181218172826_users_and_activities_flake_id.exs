defmodule Pleroma.Repo.Migrations.UsersAndActivitiesFlakeId do
  use Ecto.Migration

  # This migrates from int serial IDs to custom Flake:
  #   1- create a temporary uuid column
  #   2- fill this column with compatibility ids (see below)
  #   3- remove pkeys constraints
  #   4- update relation pkeys with the new ids
  #   5- rename the temporary column to id
  #   6- re-create the constraints
  def change do
    # Old serial int ids are transformed to 128bits with extra padding.
    # The application (in `Pleroma.FlakeId`) handles theses IDs properly as integers; to keep compatibility
    # with previously issued ids.
    #execute "update activities set external_id = CAST( LPAD( TO_HEX(id), 32, '0' ) AS uuid);"
    #execute "update users set external_id = CAST( LPAD( TO_HEX(id), 32, '0' ) AS uuid);"

    # Lock both tables to avoid a running server to meddling with our transaction
    execute "LOCK TABLE activities;"
    execute "LOCK TABLE users;"

    execute "ALTER TABLE activities DROP CONSTRAINT activities_pkey CASCADE;"
    execute "ALTER TABLE users DROP CONSTRAINT users_pkey CASCADE;"

    execute "ALTER TABLE activities ALTER COLUMN id DROP default;"
    execute "ALTER TABLE users ALTER COLUMN id DROP default;"

    execute "ALTER TABLE activities ALTER COLUMN id SET DATA TYPE uuid USING CAST( LPAD( TO_HEX(id), 32, '0' ) AS uuid);"
    execute "ALTER TABLE users ALTER COLUMN id SET DATA TYPE uuid USING CAST( LPAD( TO_HEX(id), 32, '0' ) AS uuid);"

    execute "ALTER TABLE activities ADD PRIMARY KEY (id);"
    execute "ALTER TABLE users ADD PRIMARY KEY (id);"

    # Fkeys:
    # Activities - Referenced by:
    #   TABLE "notifications" CONSTRAINT "notifications_activity_id_fkey" FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
    # Users - Referenced by:
    #  TABLE "filters" CONSTRAINT "filters_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    #  TABLE "lists" CONSTRAINT "lists_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    #  TABLE "notifications" CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    #  TABLE "oauth_authorizations" CONSTRAINT "oauth_authorizations_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id)
    #  TABLE "oauth_tokens" CONSTRAINT "oauth_tokens_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id)
    #  TABLE "password_reset_tokens" CONSTRAINT "password_reset_tokens_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id)
    #  TABLE "push_subscriptions" CONSTRAINT "push_subscriptions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    #  TABLE "websub_client_subscriptions" CONSTRAINT "websub_client_subscriptions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id)

    execute "ALTER TABLE notifications ALTER COLUMN activity_id SET DATA TYPE uuid USING CAST( LPAD( TO_HEX(activity_id), 32, '0' ) AS uuid);"
    execute "ALTER TABLE notifications ADD CONSTRAINT notifications_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE;"

    for table <- ~w(notifications filters lists oauth_authorizations oauth_tokens password_reset_tokens push_subscriptions websub_client_subscriptions) do
      execute "ALTER TABLE #{table} ALTER COLUMN user_id SET DATA TYPE uuid USING CAST( LPAD( TO_HEX(user_id), 32, '0' ) AS uuid);"
      execute "ALTER TABLE #{table} ADD CONSTRAINT #{table}_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;"
    end

  end
end
