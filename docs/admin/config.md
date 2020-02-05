# Configuring instance
You can configure your instance from admin interface. You need account with admin rights and little change in config file, which will allow settings configuration from database.

```elixir
config :pleroma, configurable_from_database: true
```

## How it works
Settings are stored in database and are applied in `runtime` after each change. Most of the settings take effect immediately, except some, which need instance reboot.

## How to set it up
You need to migrate your existing settings to the database. This task will migrate only added by user settings.
For example you add settings to `prod.secret.exs` file, only these settings will be migrated to database. For release it will be `/etc/pleroma/config.exs` or `PLEROMA_CONFIG_PATH`.
You can do this with mix task (all config files will remain untouched):

```sh tab="OTP"
 ./bin/pleroma_ctl config migrate_to_db
```

```sh tab="From Source"
mix pleroma.config migrate_to_db
```

Now you can change settings in admin interface. If `reboot time` settings were changed, pleroma must be rebooted.

<span style="color:red">**ATTENTION**</span>

**<span style="color:red">Be careful while changing the settings. Every inaccurate configuration change can break the federation or the instance load.</span>**

*Compile time settings, which require instance reboot and can break instance loading:*
- all settings inside these keys:
  - `:hackney_pools`
  - `:chat`
  - `Oban`
  - `:rate_limit`
  - `:markup`
  - `:streamer`
- partially settings inside these keys:
  - `:seconds_valid` in `Pleroma.Captcha`
  - `:proxy_remote` in `Pleroma.Upload`
  - `:upload_limit` in `:instance`
  - `:digest` in `:email_notifications`
  - `:clean_expired_tokens` in `:oauth2`
  - `:enabled` in `Pleroma.ActivityExpiration`
  - `:enabled` in `Pleroma.ScheduledActivity`
  - `:enabled` in `:gopher`

## How to dump settings from database to file

*Adding `-d` flag will delete migrated settings from database table.*

```sh tab="OTP"
 ./bin/pleroma_ctl config migrate_from_db [-d]
```

```sh tab="From Source"
mix pleroma.config migrate_from_db [-d]
```


## How to completely remove it

1. Truncate or delete all values from `config` table
```sql
TRUNCATE TABLE config;
```
2. If migrate_from_db task was runned, backup and delete `config/{env}.exported_from_db.exs`.

For `prod` env:
```bash
cd /opt/pleroma
cp config/prod.exported_from_db.exs config/exported_from_db.back
rm -rf config/prod.exported_from_db.exs
```
*If you don't want to backup settings, you can skip step with `cp` command.*

3. Set configurable_from_database to `false`.
```elixir
config :pleroma, configurable_from_database: false
```
4. Restart pleroma instance
```bash
sudo service pleroma restart
```
