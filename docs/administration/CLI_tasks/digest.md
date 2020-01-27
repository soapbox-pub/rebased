# Managing digest emails

{! backend/administration/CLI_tasks/general_cli_task_info.include !}

## Send digest email since given date (user registration date by default) ignoring user activity status.

```sh tab="OTP"
 ./bin/pleroma_ctl digest test <nickname> [<since_date>]
```

```sh tab="From Source"
mix pleroma.digest test <nickname> [<since_date>]
```


Example: 

```sh tab="OTP"
./bin/pleroma_ctl digest test donaldtheduck 2019-05-20
```

```sh tab="From Source"
mix pleroma.digest test donaldtheduck 2019-05-20
```

