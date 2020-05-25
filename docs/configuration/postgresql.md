# Optimizing your PostgreSQL performance

Pleroma performance depends to a large extent on good database performance. The default PostgreSQL settings are mostly fine, but often you can get better performance by changing a few settings.

You can use [PGTune](https://pgtune.leopard.in.ua) to get recommendations for your setup. If you do, set the "Number of Connections" field to 20, as Pleroma will only use 10 concurrent connections anyway. If you don't, it will give you advice that might even hurt your performance.

We also recommend not using the "Network Storage" option.

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

