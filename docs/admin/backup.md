# Backup/Restore your instance

## Backup

1. Stop the Pleroma service.
2. Go to the working directory of Pleroma (default is `/opt/pleroma`)
3. Run `sudo -Hu postgres pg_dump -d <pleroma_db> --format=custom -f </path/to/backup_location/pleroma.pgdump>`
4. Copy `pleroma.pgdump`, `config/prod.secret.exs` and the `uploads` folder to your backup destination. If you have other modifications, copy those changes too.
5. Restart the Pleroma service.

## Restore

1. Stop the Pleroma service.
2. Go to the working directory of Pleroma (default is `/opt/pleroma`)
3. Copy the above mentioned files back to their original position.
4. Run `sudo -Hu postgres pg_restore -d <pleroma_db> -v -1 </path/to/backup_location/pleroma.pgdump>`
5. Restart the Pleroma service.
