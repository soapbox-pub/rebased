# Managing relays

Every command should be ran with a prefix, in case of OTP releases it is `./bin/pleroma_ctl relay` and in case of source installs it's `mix pleroma.relay`.

## Follow a relay
```sh
$PREFIX follow <relay_url>
```

Example:
```sh
$PREFIX follow https://example.org/relay
```

## Unfollow a remote relay

```sh
$PREFIX unfollow <relay_url>
```

Example:
```sh
$PREFIX unfollow https://example.org/relay
```

## List relay subscriptions

```sh
$PREFIX list
```
