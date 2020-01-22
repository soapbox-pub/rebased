# Transfering the config to/from the database

!!! danger
    This is a Work In Progress, not usable just yet.

{! backend/administration/CLI_tasks/general_cli_task_info.include !}

## Transfer config from file to DB.

```sh tab="OTP"
 ./bin/pleroma_ctl config migrate_to_db
```

```sh tab="From Source"
mix pleroma.config migrate_to_db
```


## Transfer config from DB to `config/env.exported_from_db.secret.exs`

To delete transfered settings from database optional flag `-d` can be used. <env> is `prod` by default.
```sh tab="OTP"
 ./bin/pleroma_ctl config migrate_from_db [--env=<env>] [-d]
```

```sh tab="From Source"
mix pleroma.config migrate_from_db [--env=<env>] [-d]
```
