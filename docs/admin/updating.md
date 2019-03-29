# Updating your instance
1. Stop the Pleroma service.
2. Go to the working directory of Pleroma (default is `/opt/pleroma`)
3. Run `git pull`. This pulls the latest changes from upstream.
4. Run `mix deps.get`. This pulls in any new dependencies.
5. Run `mix ecto.migrate`[^1]. This task performs database migrations, if there were any.
6. Restart the Pleroma service.

[^1]: Prefix with `MIX_ENV=prod` to run it using the production config file.
