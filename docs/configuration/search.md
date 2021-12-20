# Configuring search

{! backend/administration/CLI_tasks/general_cli_task_info.include !}

## Built-in search

To use built-in search that has no external dependencies, set the search module to `Pleroma.Activity`:

> config :pleroma, Pleroma.Search, module: Pleroma.Search.DatabaseSearch

While it has no external dependencies, it has problems with performance and relevancy.

## Meilisearch

Note that it's quite a bit more memory hungry than PostgreSQL (around 4-5G for ~1.2 million
posts while idle and up to 7G while indexing initially). The disk usage for this additional index is also
around 4 gigabytes. Like [RUM](./cheatsheet.md#rum-indexing-for-full-text-search) indexes, it offers considerably
higher performance and ordering by timestamp in a reasonable amount of time.
Additionally, the search results seem to be more accurate.

Due to high memory usage, it may be best to set it up on a different machine, if running pleroma on a low-resource
computer, and use private key authentication to secure the remote search instance.

To use [meilisearch](https://www.meilisearch.com/), set the search module to `Pleroma.Search.Meilisearch`:

> config :pleroma, Pleroma.Search, module: Pleroma.Search.Meilisearch

You then need to set the address of the meilisearch instance, and optionally the private key for authentication. You might
also want to change the `initial_indexing_chunk_size` to be smaller if you're server is not very powerful, but not higher than `100_000`,
because meilisearch will refuse to process it if it's too big. However, in general you want this to be as big as possible, because meilisearch
indexes faster when it can process many posts in a single batch.

> config :pleroma, Pleroma.Search.Meilisearch,
>    url: "http://127.0.0.1:7700/",
>    private_key: "private key",
>    initial_indexing_chunk_size: 100_000

Information about setting up meilisearch can be found in the
[official documentation](https://docs.meilisearch.com/learn/getting_started/installation.html).
You probably want to start it with `MEILI_NO_ANALYTICS=true` and `MEILI_NO_CENTRY=true` environment variables,
to disable analytics.

### Private key authentication (optional)

To set the private key, use the `MEILI_MASTER_KEY` environment variable when starting. After setting the _master key_,
you have to get the _private key_, which is actually used for authentication.

=== "OTP"
    ```sh
    ./bin/pleroma_ctl search.meilisearch show-private-key <your master key here>
    ```

=== "From Source"
    ```sh
    mix pleroma.search.meilisearch show-private-key <your master key here>
    ```

This is the key you actually put into your configuration file.

### Initial indexing

After setting up the configuration, you'll want to index all of your already existsing posts. Only public posts are indexed.  You'll only
have to do it one time, but it might take a while, depending on the amount of posts your instance has seen. This is also a fairly RAM
consuming process for `meilisearch`, and it will take a lot of RAM when running if you have a lot of posts (seems to be around 5G for ~1.2
million posts while idle and up to 7G while indexing initially, but your experience may be different).

The sequence of actions is as follows:

1. First, change the configuration to use `Pleroma.Search.Meilisearch` as the search backend
2. Restart your instance, at this point it can be used while the search indexing is running, though search won't return anything
3. Start the initial indexing process (as described below with `index`),
   and wait until the task says it sent everything from the database to index
4. Wait until everything is actually indexed (by checking with `stats` as described below),
   at this point you don't have to do anything, just wait a while.

To start the initial indexing, run the `index` command:

=== "OTP"
    ```sh
    ./bin/pleroma_ctl search.meilisearch index
    ```

=== "From Source"
    ```sh
    mix pleroma.search.meilisearch index
    ```

This will show you the total amount of posts to index, and then show you the amount of posts indexed currently, until the numbers eventually
become the same. The posts are indexed in big batches and meilisearch will take some time to actually index them, even after you have
inserted all the posts into it. Depending on the amount of posts, this may be as long as several hours. To get information about the status
of indexing and how many posts have actually been indexed, use the `stats` command:

=== "OTP"
    ```sh
    ./bin/pleroma_ctl search.meilisearch stats
    ```

=== "From Source"
    ```sh
    mix pleroma.search.meilisearch stats
    ```

### Clearing the index

In case you need to clear the index (for example, to re-index from scratch, if that needs to happen for some reason), you can
use the `clear` command:

=== "OTP"
    ```sh
    ./bin/pleroma_ctl search.meilisearch clear
    ```

=== "From Source"
    ```sh
    mix pleroma.search.meilisearch clear
    ```

This will clear **all** the posts from the search index. Note, that deleted posts are also removed from index by the instance itself, so
there is no need to actually clear the whole index, unless you want **all** of it gone. That said, the index does not hold any information
that cannot be re-created from the database, it should also generally be a lot smaller than the size of your database. Still, the size
depends on the amount of text in posts.
