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

To delete transferred settings from database optional flag `-d` can be used. `<env>` is `prod` by default.

=== "OTP"
    ```sh
     ./bin/pleroma_ctl config migrate_from_db [--env=<env>] [-d]
    ```

=== "From Source"
    ```sh
    mix pleroma.config migrate_from_db [--env=<env>] [-d]
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

## Dump the saved configuration values for a specific group

e.g., this shows all the settings under `:instance`

=== "OTP"

    ```sh
    ./bin/pleroma_ctl config dump instance
    ```

=== "From Source"

    ```sh
    mix pleroma.config dump instance
    ```
