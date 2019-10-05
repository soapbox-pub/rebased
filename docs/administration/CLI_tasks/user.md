# Managing users

Every command should be ran with a prefix, in case of OTP releases it is `./bin/pleroma_ctl user` and in case of source installs it's `mix pleroma.user`.

## Create a user
```sh
$PREFIX new <nickname> <email> [<options>]
```

### Options
- `--name <name>` - the user's display name
- `--bio <bio>` - the user's bio
- `--password <password>` - the user's password
- `--moderator`/`--no-moderator` - whether the user should be a moderator
- `--admin`/`--no-admin` - whether the user should be an admin
- `-y`, `--assume-yes`/`--no-assume-yes` - whether to assume yes to all questions

## Generate an invite link
```sh
$PREFIX invite [<options>]
```

### Options
- `--expires-at DATE` - last day on which token is active (e.g. "2019-04-05")
- `--max-use NUMBER` - maximum numbers of token uses

## List generated invites
```sh
$PREFIX invites
```

## Revoke invite
```sh
$PREFIX revoke_invite <token_or_id>
```

## Delete a user
```sh
$PREFIX rm <nickname>
```

## Delete user's posts and interactions
```sh
$PREFIX delete_activities <nickname>
```

## Sign user out from all applications (delete user's OAuth tokens and authorizations)
```sh
$PREFIX sign_out <nickname>
```

## Deactivate or activate a user 
```sh
$PREFIX toggle_activated <nickname> 
```

## Unsubscribe local users from a user and deactivate the user
```sh
$PREFIX unsubscribe NICKNAME
```

## Unsubscribe local users from an instance and deactivate all accounts on it
```sh
$PREFIX unsubscribe_all_from_instance <instance>
```

## Create a password reset link for user
```sh
$PREFIX reset_password <nickname>
```

## Set the value of the given user's settings
```sh
$PREFIX set <nickname> [<options>]
```
### Options
- `--locked`/`--no-locked` - whether the user should be locked
- `--moderator`/`--no-moderator` - whether the user should be a moderator
- `--admin`/`--no-admin` - whether the user should be an admin

## Add tags to a user
```sh
$PREFIX tag <nickname> <tags>
```

## Delete tags from a user
```sh
$PREFIX untag <nickname> <tags>
```

## Toggle confirmation status of the user
```sh
$PREFIX toggle_confirmed <nickname>
```
