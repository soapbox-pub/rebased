# Database maintenance tasks

Every command should be ran with a prefix, in case of OTP releases it is `./bin/pleroma_ctl database` and in case of source installs it's `mix pleroma.database`.

!!! danger
    These mix tasks can take a long time to complete. Many of them were written to address specific database issues that happened because of bugs in migrations or other specific scenarios. Do not run these tasks "just in case" if everything is fine your instance.

## Replace embedded objects with their references

Replaces embedded objects with references to them in the `objects` table. Only needs to be ran once if the instance was created before Pleroma 1.0.5. The reason why this is not a migration is because it could significantly increase the database size after being ran, however after this `VACUUM FULL` will be able to reclaim about 20% (really depends on what is in the database, your mileage may vary) of the db size before the migration.

```sh
$PREFIX remove_embedded_objects [<options>]
```

### Options
- `--vacuum` - run `VACUUM FULL` after the embedded objects are replaced with their references

## Prune old remote posts from the database

This will prune remote posts older than 90 days (configurable with [`config :pleroma, :instance, remote_post_retention_days`](../../configuration/cheatsheet.md#instance)) from the database, they will be refetched from source when accessed.

!!! note
    The disk space will only be reclaimed after `VACUUM FULL`

```sh
$PREFIX pleroma.database prune_objects [<options>]
```

### Options
- `--vacuum` - run `VACUUM FULL` after the objects are pruned

## Create a conversation for all existing DMs

Can be safely re-run

```sh
$PREFIX bump_all_conversations
```

## Remove duplicated items from following and update followers count for all users

```sh
$PREFIX update_users_following_followers_counts
```

## Fix the pre-existing "likes" collections for all objects

```sh
$PREFIX fix_likes_collections
```
