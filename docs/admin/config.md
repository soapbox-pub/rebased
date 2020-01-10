# Configuring instance
You can configure your instance from admin interface. You need account with admin rights and little change in config file, which will allow settings configuration from database.

```elixir
config :pleroma, configurable_from_database: true
```

## How it works
Settings are stored in database and are applied in `runtime` after each change. Most of the settings take effect immediately, except some, which need instance reboot. These settings are needed in `compile time`, that's why settings are duplicated to the file.

File with duplicated settings is located in `config/{env}.exported_from_db.exs`. For prod env it will be `config/prod.exported_from_db.exs`.

## How to set it up
You need to migrate your existing settings to the database. You can do this with mix task (all config files will remain untouched):
```bash
mix pleroma.config migrate_to_db
```
Now you can change settings in admin interface. After each save, settings are duplicated to the `config/{env}.exported_from_db.exs` file.

<span style="color:red">**ATTENTION**</span>

**<span style="color:red">Be careful while changing the settings. Every inaccurate configuration change can break the federation or the instance load.</span>**

*Compile time settings, which require instance reboot and can break instance loading:*
- all settings inside these keys:
  - `:hackney_pools`
  - `:chat`
  - `Pleroma.Web.Endpoint`
- partially settings inside these keys:
  - `:seconds_valid` in `Pleroma.Captcha`
  - `:proxy_remote` in `Pleroma.Upload`
  - `:upload_limit` in `:instance`

## How to remove it

1. Truncate or delete all values from `config` table
```sql
TRUNCATE TABLE config;
```
2. Delete `config/{env}.exported_from_db.exs`.

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
