# Database maintenance tasks

{! backend/administration/CLI_tasks/general_cli_task_info.include !}

!!! danger
    These mix tasks can take a long time to complete. Many of them were written to address specific database issues that happened because of bugs in migrations or other specific scenarios. Do not run these tasks "just in case" if everything is fine your instance.

## Replace embedded objects with their references

Replaces embedded objects with references to them in the `objects` table. Only needs to be ran once if the instance was created before Pleroma 1.0.5. The reason why this is not a migration is because it could significantly increase the database size after being ran, however after this `VACUUM FULL` will be able to reclaim about 20% (really depends on what is in the database, your mileage may vary) of the db size before the migration.

```sh tab="OTP"
./bin/pleroma_ctl database remove_embedded_objects [<options>]
```

```sh tab="From Source"
mix pleroma.database remove_embedded_objects [<options>]
```

### Options
- `--vacuum` - run `VACUUM FULL` after the embedded objects are replaced with their references

## Prune old remote posts from the database

This will prune remote posts older than 90 days (configurable with [`config :pleroma, :instance, remote_post_retention_days`](../../configuration/cheatsheet.md#instance)) from the database, they will be refetched from source when accessed.

!!! danger
    The disk space will only be reclaimed after `VACUUM FULL`. You may run out of disk space during the execution of the task or vacuuming if you don't have about 1/3rds of the database size free.

```sh tab="OTP"
./bin/pleroma_ctl database prune_objects [<options>]
```

```sh tab="From Source"
mix pleroma.database prune_objects [<options>]
```

### Options
- `--vacuum` - run `VACUUM FULL` after the objects are pruned

## Create a conversation for all existing DMs

Can be safely re-run

```sh tab="OTP"
./bin/pleroma_ctl database bump_all_conversations
```

```sh tab="From Source"
mix pleroma.database bump_all_conversations
```

## Remove duplicated items from following and update followers count for all users

```sh tab="OTP"
./bin/pleroma_ctl database update_users_following_followers_counts
```

```sh tab="From Source"
mix pleroma.database update_users_following_followers_counts
```

## Fix the pre-existing "likes" collections for all objects

```sh tab="OTP"
./bin/pleroma_ctl database fix_likes_collections
```

```sh tab="From Source"
mix pleroma.database fix_likes_collections
```
