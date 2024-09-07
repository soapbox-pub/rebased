# Migrating from Akkoma

## Database migration

To rollback Akkoma-specific migrations:

- OTP: `./bin/pleroma_ctl rollback --migrations-path priv/repo/optional_migrations/akkoma_rollbacks`
- From Source: `mix ecto.rollback --migrations-path priv/repo/optional_migrations/akkoma_rollbacks`

Then, just

- OTP: `./bin/pleroma_ctl migrate`
- From Source: `mix ecto.migrate`

to apply Pleroma database migrations.