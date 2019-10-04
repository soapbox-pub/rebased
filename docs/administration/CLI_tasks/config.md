# Transfering the config to/from the database

!!! danger
    This is a Work In Progress, not usable just yet.

Every command should be ran with a prefix, in case of OTP releases it is `./bin/pleroma_ctl config` and in case of source installs it's
`mix pleroma.config`.

## Transfer config from file to DB.

```sh
$PREFIX migrate_to_db
```

## Transfer config from DB to `config/env.exported_from_db.secret.exs`

```sh
$PREFIX migrate_from_db <env>
```
