# Managing uploads

Every command should be ran with a prefix, in case of OTP releases it is `./bin/pleroma_ctl uploads` and in case of source installs it's `mix pleroma.uploads`.

## Migrate uploads from local to remote storage
```sh
$PREFIX migrate_local <target_uploader> [<options>]
```
### Options
- `--delete` - delete local uploads after migrating them to the target uploader

A list of available uploaders can be seen in [Configuration Cheat Sheet](../../configuration/cheatsheet.md#pleromaupload)
