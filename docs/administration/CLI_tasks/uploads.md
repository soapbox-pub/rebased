# Managing uploads

{! backend/administration/CLI_tasks/general_cli_task_info.include !}

## Migrate uploads from local to remote storage
```sh tab="OTP"
 ./bin/pleroma_ctl uploads migrate_local <target_uploader> [option ...]
```

```sh tab="From Source"
mix pleroma.uploads migrate_local <target_uploader> [option ...]
```

### Options
- `--delete` - delete local uploads after migrating them to the target uploader

A list of available uploaders can be seen in [Configuration Cheat Sheet](../../configuration/cheatsheet.md#pleromaupload)
