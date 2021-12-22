# Transfering the config to/from the database

{! backend/administration/CLI_tasks/general_cli_task_info.include !}

## Transfer config from file to DB.

!!! note
    You need to add the following to your config before executing this command:

    ```elixir
    config :pleroma, configurable_from_database: true
    ```

=== "OTP"

    ```sh
    ./bin/pleroma_ctl config migrate_to_db
    ```

=== "From Source"

    ```sh
    mix pleroma.config migrate_to_db
    ```

## Transfer config from DB to `config/env.exported_from_db.secret.exs`

!!! note
    In-Database configuration will still be applied after executing this command unless you set the following in your config:

    ```elixir
    config :pleroma, configurable_from_database: false
    ```

Options:

- `<path>` - where to save migrated config. E.g. `--path=/tmp`. If file saved into non standart folder, you must manually copy file into directory where Pleroma can read it. For OTP install path will be `PLEROMA_CONFIG_PATH` or `/etc/pleroma`. For installation from source - `config` directory in the pleroma folder.
- `<env>` - environment, for which is migrated config. By default is `prod`.
- To delete transferred settings from database optional flag `-d` can be used

=== "OTP"
    ```sh
     ./bin/pleroma_ctl config migrate_from_db [--env=<env>] [-d] [--path=<path>]
    ```

=== "From Source"
    ```sh
    mix pleroma.config migrate_from_db [--env=<env>] [-d] [--path=<path>]
    ```

## Dump all of the config settings defined in the database

=== "OTP"

    ```sh
     ./bin/pleroma_ctl config dump
    ```

=== "From Source"

    ```sh
    mix pleroma.config dump
    ```

## List individual configuration groups in the database

=== "OTP"

    ```sh
     ./bin/pleroma_ctl config groups
    ```

=== "From Source"

    ```sh
    mix pleroma.config groups
    ```

## Dump the saved configuration values for a specific group or key

e.g., this shows all the settings under `config :pleroma`

=== "OTP"

    ```sh
    ./bin/pleroma_ctl config dump pleroma
    ```

=== "From Source"

    ```sh
    mix pleroma.config dump pleroma
    ```

To get values under a specific key:

e.g., this shows all the settings under `config :pleroma, :instance`

=== "OTP"

    ```sh
    ./bin/pleroma_ctl config dump pleroma instance
    ```

=== "From Source"

    ```sh
    mix pleroma.config dump pleroma instance
    ```

## Delete the saved configuration values for a specific group or key

e.g., this deletes all the settings under `config :tesla`

=== "OTP"

    ```sh
    ./bin/pleroma_ctl config delete [--force] tesla
    ```

=== "From Source"

    ```sh
    mix pleroma.config delete [--force] tesla
    ```

To delete values under a specific key:

e.g., this deletes all the settings under `config :phoenix, :stacktrace_depth`

=== "OTP"

    ```sh
    ./bin/pleroma_ctl config delete [--force] phoenix stacktrace_depth
    ```

=== "From Source"

    ```sh
    mix pleroma.config delete [--force] phoenix stacktrace_depth
    ```

## Remove all settings from the database

This forcibly removes all saved values in the database.

=== "OTP"

    ```sh
    ./bin/pleroma_ctl config [--force] reset
    ```

=== "From Source"

    ```sh
    mix pleroma.config [--force] reset
    ```
