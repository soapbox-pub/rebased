# Managing users

{! backend/administration/CLI_tasks/general_cli_task_info.include !}

## Create a user

```sh tab="OTP"
./bin/pleroma_ctl user new <email> [<options>]
```

```sh tab="From Source"
mix pleroma.user new <email> [<options>]
```


### Options
- `--name <name>` - the user's display name
- `--bio <bio>` - the user's bio
- `--password <password>` - the user's password
- `--moderator`/`--no-moderator` - whether the user should be a moderator
- `--admin`/`--no-admin` - whether the user should be an admin
- `-y`, `--assume-yes`/`--no-assume-yes` - whether to assume yes to all questions

## List local users
```sh tab="OTP"
 ./bin/pleroma_ctl user list
```

```sh tab="From Source"
mix pleroma.user list
```


## Generate an invite link
```sh tab="OTP"
 ./bin/pleroma_ctl user invite [<options>]
```

```sh tab="From Source"
mix pleroma.user invite [<options>]
```


### Options
- `--expires-at DATE` - last day on which token is active (e.g. "2019-04-05")
- `--max-use NUMBER` - maximum numbers of token uses

## List generated invites
```sh tab="OTP"
 ./bin/pleroma_ctl user invites
```

```sh tab="From Source"
mix pleroma.user invites
```


## Revoke invite
```sh tab="OTP"
 ./bin/pleroma_ctl user revoke_invite <token_or_id>
```

```sh tab="From Source"
mix pleroma.user revoke_invite <token_or_id>
```


## Delete a user
```sh tab="OTP"
 ./bin/pleroma_ctl user rm <nickname>
```

```sh tab="From Source"
mix pleroma.user rm <nickname>
```


## Delete user's posts and interactions
```sh tab="OTP"
 ./bin/pleroma_ctl user delete_activities <nickname>
```

```sh tab="From Source"
mix pleroma.user delete_activities <nickname>
```


## Sign user out from all applications (delete user's OAuth tokens and authorizations)
```sh tab="OTP"
 ./bin/pleroma_ctl user sign_out <nickname>
```

```sh tab="From Source"
mix pleroma.user sign_out <nickname>
```


## Deactivate or activate a user 
```sh tab="OTP"
 ./bin/pleroma_ctl user toggle_activated <nickname> 
```

```sh tab="From Source"
mix pleroma.user toggle_activated <nickname> 
```


## Unsubscribe local users from a user and deactivate the user
```sh tab="OTP"
 ./bin/pleroma_ctl user unsubscribe NICKNAME
```

```sh tab="From Source"
mix pleroma.user unsubscribe NICKNAME
```


## Unsubscribe local users from an instance and deactivate all accounts on it
```sh tab="OTP"
 ./bin/pleroma_ctl user unsubscribe_all_from_instance <instance>
```

```sh tab="From Source"
mix pleroma.user unsubscribe_all_from_instance <instance>
```


## Create a password reset link for user
```sh tab="OTP"
 ./bin/pleroma_ctl user reset_password <nickname>
```

```sh tab="From Source"
mix pleroma.user reset_password <nickname>
```


## Set the value of the given user's settings
```sh tab="OTP"
 ./bin/pleroma_ctl user set <nickname> [<options>]
```

```sh tab="From Source"
mix pleroma.user set <nickname> [<options>]
```

### Options
- `--locked`/`--no-locked` - whether the user should be locked
- `--moderator`/`--no-moderator` - whether the user should be a moderator
- `--admin`/`--no-admin` - whether the user should be an admin

## Add tags to a user
```sh tab="OTP"
 ./bin/pleroma_ctl user tag <nickname> <tags>
```

```sh tab="From Source"
mix pleroma.user tag <nickname> <tags>
```


## Delete tags from a user
```sh tab="OTP"
 ./bin/pleroma_ctl user untag <nickname> <tags>
```

```sh tab="From Source"
mix pleroma.user untag <nickname> <tags>
```


## Toggle confirmation status of the user
```sh tab="OTP"
 ./bin/pleroma_ctl user toggle_confirmed <nickname>
```

```sh tab="From Source"
mix pleroma.user toggle_confirmed <nickname>
```

