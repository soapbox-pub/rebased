# Updating your instance

You should **always check the release notes/changelog** in case there are config deprecations, special update special update steps, etc.

Besides that, doing the following is generally enough:

## For OTP installations

```sh
# Download the new release
su pleroma -s $SHELL -lc "./bin/pleroma_ctl update"

# Migrate the database, you are advised to stop the instance before doing that
su pleroma -s $SHELL -lc "./bin/pleroma_ctl migrate"
```

## For from source installations (using git)

1. Go to the working directory of Pleroma (default is `/opt/pleroma`)
2. Run `git pull`. This pulls the latest changes from upstream.
3. Run `mix deps.get`. This pulls in any new dependencies.
4. Stop the Pleroma service.
5. Run `mix ecto.migrate`[^1]. This task performs database migrations, if there were any.
6. Start the Pleroma service.

[^1]: Prefix with `MIX_ENV=prod` to run it using the production config file.
