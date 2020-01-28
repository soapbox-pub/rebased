# Managing emails

{! backend/administration/CLI_tasks/general_cli_task_info.include !}

## Send test email (instance email by default)

```sh tab="OTP"
 ./bin/pleroma_ctl email test [--to <destination email address>]
```

```sh tab="From Source"
mix pleroma.email test [--to <destination email address>]
```


Example: 

```sh tab="OTP"
./bin/pleroma_ctl email test --to root@example.org
```

```sh tab="From Source"
mix pleroma.email test --to root@example.org
```
