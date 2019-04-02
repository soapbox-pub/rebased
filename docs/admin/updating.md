# Updating your instance
1. Go to the working directory of Pleroma (default is `/opt/pleroma`)
2. Run `git pull`. This pulls the latest changes from upstream.
3. Run `mix deps.get`. This pulls in any new dependencies.
4. Stop the Pleroma service.
5. Run `mix ecto.migrate`[^1]. This task performs database migrations, if there were any.
6. Start the Pleroma service.

[^1]: Prefix with `MIX_ENV=prod` to run it using the production config file.
