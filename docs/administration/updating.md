# Updating your instance

You should **always check the [release notes/changelog](https://git.pleroma.social/pleroma/pleroma/-/releases)** in case there are config deprecations, special update steps, etc.

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
2. Run `git checkout <tagged release>` [^1]. e.g. `git checkout v2.4.5` This pulls the [tagged release](https://git.pleroma.social/pleroma/pleroma/-/releases) from upstream.
3. Run `mix deps.get` [^1]. This pulls in any new dependencies.
4. Stop the Pleroma service.
5. Run `mix ecto.migrate` [^1] [^2]. This task performs database migrations, if there were any.
6. Start the Pleroma service.

[^1]: Depending on which install guide you followed (for example on Debian/Ubuntu), you want to run `git` and `mix` tasks as `pleroma` user by adding `sudo -Hu pleroma` before the command.
[^2]: Prefix with `MIX_ENV=prod` to run it using the production config file.
