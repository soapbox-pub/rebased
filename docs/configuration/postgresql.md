# Optimizing PostgreSQL performance

Pleroma performance is largely dependent on performance of the underlying database. Better performance can be achieved by adjusting a few settings.

## PGTune

[PgTune](https://pgtune.leopard.in.ua) can be used to get recommended settings. Be sure to set "Number of Connections" to 20, otherwise it might produce settings hurtful to database performance. It is also recommended to not use "Network Storage" option.

## Disable generic query plans

When PostgreSQL receives a query, it decides on a strategy for searching the requested data, this is called a query plan. The query planner has two modes: generic and custom. Generic makes a plan for all queries of the same shape, ignoring the parameters, which is then cached and reused. Custom, on the contrary, generates a unique query plan based on query parameters.

By default PostgreSQL has an algorithm to decide which mode is more efficient for particular query, however this algorithm has been observed to be wrong on some of the queries Pleroma sends, leading to serious performance loss. Therefore, it is recommended to disable generic mode.


Pleroma already avoids generic query plans by default, however the method it uses is not the most efficient because it needs to be compatible with all supported PostgreSQL versions. For PostgreSQL 12 and higher additional performance can be gained by adding the following to Pleroma configuration:
```elixir
config :pleroma, Pleroma.Repo,
  prepare: :named,
  parameters: [
    plan_cache_mode: "force_custom_plan"
  ]
```

A more detailed explaination of the issue can be found at <https://blog.soykaf.com/post/postgresql-elixir-troubles/>.

## Example configurations

Here are some configuration suggestions for PostgreSQL 10+.

### 1GB RAM, 1 CPU
```
shared_buffers = 256MB
effective_cache_size = 768MB
maintenance_work_mem = 64MB
work_mem = 13107kB
```

### 2GB RAM, 2 CPU
```
shared_buffers = 512MB
effective_cache_size = 1536MB
maintenance_work_mem = 128MB
work_mem = 26214kB
max_worker_processes = 2
max_parallel_workers_per_gather = 1
max_parallel_workers = 2
```
