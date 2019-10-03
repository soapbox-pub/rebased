# Managing digest emails
Every command should be ran with a prefix, in case of OTP releases it is `./bin/pleroma_ctl digest` and in case of source installs it's `mix pleroma.digest`.

## Send digest email since given date (user registration date by default) ignoring user activity status.

```sh
$PREFIX test <nickname> [<since_date>]
```

Example: 
```sh
$PREFIX test donaldtheduck 2019-05-20
```
