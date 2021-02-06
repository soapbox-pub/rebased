# Database maintenance tasks

{! backend/administration/CLI_tasks/general_cli_task_info.include !}

!!! danger
    These mix tasks can take a long time to complete. Many of them were written to address specific database issues that happened because of bugs in migrations or other specific scenarios. Do not run these tasks "just in case" if everything is fine your instance.

## Replace embedded objects with their references

Replaces embedded objects with references to them in the `objects` table. Only needs to be ran once if the instance was created before Pleroma 1.0.5. The reason why this is not a migration is because it could significantly increase the database size after being ran, however after this `VACUUM FULL` will be able to reclaim about 20% (really depends on what is in the database, your mileage may vary) of the db size before the migration.

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database remove_embedded_objects [option ...]
    ```

=== "From Source"

    ```sh
    mix pleroma.database remove_embedded_objects [option ...]
    ```


### Options
- `--vacuum` - run `VACUUM FULL` after the embedded objects are replaced with their references

## Prune old remote posts from the database

This will prune remote posts older than 90 days (configurable with [`config :pleroma, :instance, remote_post_retention_days`](../../configuration/cheatsheet.md#instance)) from the database, they will be refetched from source when accessed.

!!! danger
    The disk space will only be reclaimed after `VACUUM FULL`. You may run out of disk space during the execution of the task or vacuuming if you don't have about 1/3rds of the database size free.

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database prune_objects [option ...]
    ```

=== "From Source"

    ```sh
    mix pleroma.database prune_objects [option ...]
    ```

### Options
- `--vacuum` - run `VACUUM FULL` after the objects are pruned

## Create a conversation for all existing DMs

Can be safely re-run

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database bump_all_conversations
    ```

=== "From Source"

    ```sh
    mix pleroma.database bump_all_conversations
    ```

## Remove duplicated items from following and update followers count for all users

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database update_users_following_followers_counts
    ```

=== "From Source"

    ```sh
    mix pleroma.database update_users_following_followers_counts
    ```

## Fix the pre-existing "likes" collections for all objects

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database fix_likes_collections
    ```

=== "From Source"

    ```sh
    mix pleroma.database fix_likes_collections
    ```

## Vacuum the database

### Analyze

Running an `analyze` vacuum job can improve performance by updating statistics used by the query planner. **It is safe to cancel this.**

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database vacuum analyze
    ```

=== "From Source"

    ```sh
    mix pleroma.database vacuum analyze
    ```

### Full

Running a `full` vacuum job rebuilds your entire database by reading all of the data and rewriting it into smaller
and more compact files with an optimized layout. This process will take a long time and use additional disk space as
it builds the files side-by-side the existing database files. It can make your database faster and use less disk space,
but should only be run if necessary. **It is safe to cancel this.**

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database vacuum full
    ```

=== "From Source"

    ```sh
    mix pleroma.database vacuum full
    ```

## Add expiration to all local statuses

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database ensure_expiration
    ```

=== "From Source"

    ```sh
    mix pleroma.database ensure_expiration
    ```

## Change Text Search Configuration

Change `default_text_search_config` for database and (if necessary) text_search_config used in index, then rebuild index (it may take time). 

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database set_text_search_config english
    ```

=== "From Source"

    ```sh
    mix pleroma.database set_text_search_config english
    ```

See [PostgreSQL documentation](https://www.postgresql.org/docs/current/textsearch-configuration.html) and `docs/configuration/howto_search_cjk.md` for more detail.
