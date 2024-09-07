# Migrating from Akkoma

## Database migration

> Note: You will lose data related about Akkoma-specific features, including: MastoFE settings, user frontend profiles, status auto-expiration config and DM restrictions. Consider taking a backup.

To rollback Akkoma-specific migrations:

- OTP: `./bin/pleroma_ctl rollback --migrations-path priv/repo/optional_migrations/akkoma_rollbacks`
- From Source: `mix ecto.rollback --migrations-path priv/repo/optional_migrations/akkoma_rollbacks`

Then, just

- OTP: `./bin/pleroma_ctl migrate`
- From Source: `mix ecto.migrate`

to apply Pleroma database migrations.