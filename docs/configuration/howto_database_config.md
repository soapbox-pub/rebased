# How to activate Pleroma in-database configuration
## Explanation

The configuration of Pleroma has traditionally been managed with a config file, e.g. `config/prod.secret.exs`. This method requires a restart of the application for any configuration changes to take effect. We have made it possible to control most settings in the AdminFE interface after running a migration script.

## Migration to database config

1. Stop your Pleroma instance and edit your Pleroma config to enable database configuration: 

  ```
  config :pleroma, configurable_from_database: true
  ```

2. Run the mix task to migrate to the database. You'll receive some debugging output and a few messages informing you of what happened.

  **Source:**
  
  ```
  $ mix pleroma.config migrate_to_db
  ```
  
  or
  
  **OTP:**
  
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
  
3. It is recommended to backup your config file now.
  ```
  cp config/dev.secret.exs config/dev.secret.exs.orig
  ```
  
4. Now you can edit your config file and strip it down to the only settings which are not possible to control in the database. e.g., the Postgres and webserver (Endpoint) settings cannot be controlled in the database because the application needs the settings to start up and access the database.

 ⚠️ **THIS IS NOT REQUIRED**
 
 Any settings in the database will override those in the config file, but you may find it less confusing if the setting is only declared in one place.

 A non-exhaustive list of settings that are only possible in the config file include the following:

* config :pleroma, Pleroma.Web.Endpoint
* config :pleroma, Pleroma.Repo
* config :pleroma, configurable_from_database
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

5. Start your instance back up and you can now access the Settings tab in AdminFE.


## Reverting back from database config

1. Stop your Pleroma instance.

2. Run the mix task to migrate back from the database. You'll receive some debugging output and a few messages informing you of what happened.

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

3. The in-database configuration still exists, but it will not be used if you remove `config :pleroma, configurable_from_database: true` from your config.

## Debugging

### Clearing database config
You can clear the database config by truncating the `config` table in the database. e.g.,

```
psql -d pleroma_dev
pleroma_dev=# TRUNCATE config;
TRUNCATE TABLE
```

Additionally, every time you migrate the configuration to the database the config table is automatically truncated to ensure a clean migration.

### Manually removing a setting
If you encounter a situation where the server cannot run properly because of an invalid setting in the database and this is preventing you from accessing AdminFE, you can manually remove the offending setting if you know which one it is.

e.g., here is an example showing a minimal configuration in the database. Only the `config :pleroma, :instance` settings are in the table:

```
psql -d pleroma_dev
pleroma_dev=# select * from config;
 id |    key    |                           value                            |     inserted_at     |     updated_at      |  group
----+-----------+------------------------------------------------------------+---------------------+---------------------+----------
  1 | :instance | \x836c0000000168026400046e616d656d00000007426c65726f6d616a | 2020-07-12 15:33:29 | 2020-07-12 15:33:29 | :pleroma
(1 row)
pleroma_dev=# delete from config where key = ':instance' and group = ':pleroma';
DELETE 1
```

Now the `config :pleroma, :instance` settings have been removed from the database.
