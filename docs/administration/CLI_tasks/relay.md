# Managing relays

{! backend/administration/CLI_tasks/general_cli_task_info.include !}

## Follow a relay

```sh tab="OTP"
./bin/pleroma_ctl relay follow <relay_url>
```

```sh tab="From Source"
mix pleroma.relay follow <relay_url>
```

## Unfollow a remote relay

```sh tab="OTP"
./bin/pleroma_ctl relay unfollow <relay_url>
```

```sh tab="From Source"
mix pleroma.relay unfollow <relay_url>
```

## List relay subscriptions

```sh tab="OTP"
./bin/pleroma_ctl relay list
```

```sh tab="From Source"
mix pleroma.relay list
```
