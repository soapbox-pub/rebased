# Backup/Restore/Move/Remove your instance

## Backup

1. Stop the Pleroma service.
2. Go to the working directory of Pleroma (default is `/opt/pleroma`)
3. Run `sudo -Hu postgres pg_dump -d <pleroma_db> --format=custom -f </path/to/backup_location/pleroma.pgdump>` (make sure the postgres user has write access to the destination file)
4. Copy `pleroma.pgdump`, `config/prod.secret.exs` and the `uploads` folder to your backup destination. If you have other modifications, copy those changes too.
5. Restart the Pleroma service.

## Restore/Move

1. Optionally reinstall Pleroma (either on the same server or on another server if you want to move servers). Try to use the same database name.
2. Stop the Pleroma service.
3. Go to the working directory of Pleroma (default is `/opt/pleroma`)
4. Copy the above mentioned files back to their original position.
5. Drop the existing database and recreate an empty one `sudo -Hu postgres psql -c 'DROP DATABASE <pleroma_db>;';` `sudo -Hu postgres psql -c 'CREATE DATABASE <pleroma_db>;';`
6. Run `sudo -Hu postgres pg_restore -d <pleroma_db> -v -1 </path/to/backup_location/pleroma.pgdump>`
7. If you installed a newer Pleroma version, you should run `mix ecto.migrate`[^1]. This task performs database migrations, if there were any.
8. Restart the Pleroma service.

[^1]: Prefix with `MIX_ENV=prod` to run it using the production config file.

## Remove

1. Optionally you can remove the users of your instance. This will trigger delete requests for their accounts and posts. Note that this is 'best effort' and doesn't mean that all traces of your instance will be gone from the fediverse.
    * You can do this from the admin-FE where you can select all local users and delete the accounts using the *Moderate multiple users* dropdown.
    * You can also list local users and delete them individualy using the CLI tasks for [Managing users](./CLI_tasks/user.md).
2. Stop the Pleroma service `systemctl stop pleroma`
3. Disable pleroma from systemd `systemctl disable pleroma`
4. Remove the files and folders you created during installation (see installation guide). This includes the pleroma, nginx and systemd files and folders.
5. Reload nginx now that the configuration is removed `systemctl reload nginx`
6. Remove the database and database user `sudo -Hu postgres psql -c 'DROP DATABASE <pleroma_db>;';` `sudo -Hu postgres psql -c 'DROP USER <pleroma_db>;';`
7. Remove the system user `userdel pleroma`
8. Remove the dependencies that you don't need anymore (see installation guide). Make sure you don't remove packages that are still needed for other software that you have running!
