# How to activate Pleroma in-database configuration
## Explanation

The configuration of Pleroma has traditionally been managed with a config file, e.g. `config/prod.secret.exs`. This method requires a restart of the application for any configuration changes to take effect. We have made it possible to control most settings in the AdminFE interface after running a migration script.

## Migration to database config

1. Run the mix task to migrate to the database. You'll receive some debugging output and a few messages informing you of what happened.

  **Source:**

  ```
  $ mix pleroma.config migrate_to_db
  ```

  or

  **OTP:**

  *Note: OTP users need Pleroma to be running for `pleroma_ctl` commands to work*

  ```
  $ ./bin/pleroma_ctl config migrate_to_db
  ```

  ```
   10:04:34.155 [debug] QUERY OK source="config" db=1.6ms decode=2.0ms queue=33.5ms idle=0.0ms
    SELECT c0."id", c0."key", c0."group", c0."value", c0."inserted_at", c0."updated_at" FROM "config" AS c0 []
    Migrating settings from file: /home/pleroma/config/dev.secret.exs

   10:04:34.240 [debug] QUERY OK db=4.5ms queue=0.3ms idle=92.2ms
    TRUNCATE config; []

   10:04:34.244 [debug] QUERY OK db=2.8ms queue=0.3ms idle=97.2ms
    ALTER SEQUENCE config_id_seq RESTART; []

   10:04:34.256 [debug] QUERY OK source="config" db=0.8ms queue=1.4ms idle=109.8ms
   SELECT c0."id", c0."key", c0."group", c0."value", c0."inserted_at", c0."updated_at" FROM "config" AS c0 WHERE ((c0."group" = $1) AND (c0."key" = $2)) [":pleroma", ":instance"]

   10:04:34.292 [debug] QUERY OK db=2.6ms queue=1.7ms idle=137.7ms
   INSERT INTO "config" ("group","key","value","inserted_at","updated_at") VALUES ($1,$2,$3,$4,$5) RETURNING "id" [":pleroma", ":instance", <<131, 108, 0, 0, 0, 1, 104, 2, 100, 0, 4, 110, 97, 109, 101, 109, 0, 0, 0, 7, 66, 108, 101, 114, 111, 109, 97, 106>>, ~N[2020-07-12 15:04:34], ~N[2020-07-12 15:04:34]]
   Settings for key instance migrated.
   Settings for group :pleroma migrated.
  ```

2. It is recommended to backup your config file now.

  ```
  cp config/dev.secret.exs config/dev.secret.exs.orig
  ```

3. Edit your Pleroma config to enable database configuration:

  ```
  config :pleroma, configurable_from_database: true
  ```

4. ⚠️ **THIS IS NOT REQUIRED** ⚠️

  Now you can edit your config file and strip it down to the only settings which are not possible to control in the database. e.g., the Postgres (Repo) and webserver (Endpoint) settings cannot be controlled in the database because the application needs the settings to start up and access the database.

  Any settings in the database will override those in the config file, but you may find it less confusing if the setting is only declared in one place.

  A non-exhaustive list of settings that are only possible in the config file include the following:

  * config :pleroma, Pleroma.Web.Endpoint
  * config :pleroma, Pleroma.Repo
  * config :pleroma, configurable\_from\_database
  * config :pleroma, :database, rum_enabled
  * config :pleroma, :connections_pool

  Here is an example of a server config stripped down after migration:

  ```
  use Mix.Config

  config :pleroma, Pleroma.Web.Endpoint,
    url: [host: "cool.pleroma.site", scheme: "https", port: 443]

  config :pleroma, Pleroma.Repo,
    adapter: Ecto.Adapters.Postgres,
    username: "pleroma",
    password: "MySecretPassword",
    database: "pleroma_prod",
    hostname: "localhost"

  config :pleroma, configurable_from_database: true
  ```

5. Restart your instance and you can now access the Settings tab in AdminFE.


## Reverting back from database config

1. Run the mix task to migrate back from the database. You'll receive some debugging output and a few messages informing you of what happened.

  **Source:**

  ```
  $ mix pleroma.config migrate_from_db
  ```

  or

  **OTP:**

  ```
  $ ./bin/pleroma_ctl config migrate_from_db
  ```

  ```
  10:26:30.593 [debug] QUERY OK source="config" db=9.8ms decode=1.2ms queue=26.0ms idle=0.0ms
  SELECT c0."id", c0."key", c0."group", c0."value", c0."inserted_at", c0."updated_at" FROM "config" AS c0 []

  10:26:30.659 [debug] QUERY OK source="config" db=1.1ms idle=80.7ms
  SELECT c0."id", c0."key", c0."group", c0."value", c0."inserted_at", c0."updated_at" FROM "config" AS c0 []
  Database configuration settings have been saved to config/dev.exported_from_db.secret.exs
  ```

2. Remove `config :pleroma, configurable_from_database: true` from your config. The in-database configuration still exists, but it will not be used. Future migrations will erase the database config before importing your config file again.

3. Restart your instance.

## Debugging

### Clearing database config
You can clear the database config with the following command:

  **Source:**

  ```
  $ mix pleroma.config reset
  ```

  or

  **OTP:**

  ```
  $ ./bin/pleroma_ctl config reset
  ```

Additionally, every time you migrate the configuration to the database the config table is automatically truncated to ensure a clean migration.

### Manually removing a setting
If you encounter a situation where the server cannot run properly because of an invalid setting in the database and this is preventing you from accessing AdminFE, you can manually remove the offending setting if you know which one it is.

e.g., here is an example showing a the removal of the `config :pleroma, :instance` settings:

  **Source:**

  ```
  $ mix pleroma.config delete pleroma instance
  Are you sure you want to continue? [n]  y
  config :pleroma, :instance deleted from the ConfigDB.
  ```

  or

  **OTP:**

  ```
  $ ./bin/pleroma_ctl config delete pleroma instance
  Are you sure you want to continue? [n]  y
  config :pleroma, :instance deleted from the ConfigDB.
  ```

Now the `config :pleroma, :instance` settings have been removed from the database.
