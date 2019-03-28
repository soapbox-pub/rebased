# Admin tasks
## Important

If your instance is running in prod mode (most likely it is) make sure to prefix every command with `MIX_ENV=prod`.

## User management

It is possible to obtain a list of all available tasks with their options by executing `mix help pleroma.user`

### Adding users

Use `mix pleroma.user invite` to generate an invite link for a new user.

Also, `mix pleroma.user new NICKNAME EMAIL [OPTION...]` can be used to register an account.

### Making a user a moderator/admin/locked

Run `mix pleroma.user set username --[no-]moderator` to make user a moderator or remove the moderator status.

To make the user admin or locked use `mix pleroma.user set NICKNAME --[no-]admin` and `mix pleroma.user set NICKNAME --[no-]locked` respectively

### Resetting a password

Run `mix pleroma.user reset_password NICKNAME` to generate a password reset link that you can then send to the user.

### Banning users

Run `mix pleroma.user rm NICKNAME` to remove a local account.

To deactivate(block from the server completely)/reactivate local and remote user accounts run:

`mix pleroma.user toggle_activated NICKNAME@instancename`

## Relay managment

It is possible to obtain a list of all available tasks with their options by executing `mix help pleroma.relay`

### Following a relay

Run `mix pleroma.relay follow RELAY_URL`

### Unfollowing a relay

Run `mix pleroma.relay unfollow RELAY_URL`
