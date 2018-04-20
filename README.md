# Pleroma

## About Pleroma

Pleroma is an OStatus-compatible social networking server written in Elixir, compatible with GNU Social and Mastodon. It is high-performance and can run on small devices like a Raspberry Pi.

For clients it supports both the [GNU Social API with Qvitter extensions](https://twitter-api.readthedocs.io/en/latest/index.html) and the [Mastodon client API](https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md).

Mobile clients that are known to work well:

* Twidere
* Tusky
* Pawoo (Android + iOS)
* Subway Tooter
* Amaroq (iOS)
* Tootdon (Android + iOS)
* Tootle (iOS)

No release has been made yet, but several servers have been online for months already. If you want to run your own server, feel free to contact us at @lain@pleroma.soykaf.com or in our dev chat at #pleroma on freenode or via matrix at https://matrix.heldscal.la/#/room/#freenode_#pleroma:matrix.org.

## Installation

### Docker

While we don't provide docker files, other people have written very good ones. Take a look at https://github.com/Angristan/dockerfiles/tree/master/pleroma or https://github.com/sn0w/pleroma-docker.

### Dependencies

* Postgresql version 9.6 or newer
* Elixir version 1.5 or newer. If your distribution only has an old version available, check [Elixir's install page](https://elixir-lang.org/install.html)
* Build-essential tools

### Configuration

  * Run `mix deps.get` to install elixir dependencies.

  * Run `mix generate_config`. This will ask you a few questions about your instance and generate a configuration file in `config/generated_config.exs`. Check that and copy it to either `config/dev.secret.exs` or `config/prod.secret.exs`. It will also create a `config/setup_db.psql`; you may want to double-check this file in case you wanted a different username, or database name than the default. Then you need to run the script as PostgreSQL superuser (i.e. `sudo su postgres -c "psql -f config/setup_db.psql"`). It will create a pleroma db user, database and will setup needed extensions that need to be set up. Postgresql super-user privileges are only needed for this step.

  * For these next steps, the default will be to run pleroma using the dev configuration file, `config/dev.secret.exs`. To run them using the prod config file, prefix each command at the shell with `MIX_ENV=prod`. For example: `MIX_ENV=prod mix phx.server`.

  * Run `mix ecto.migrate` to run the database migrations. You will have to do this again after certain updates.

  * You can check if your instance is configured correctly by running it with `mix phx.server` and checking the instance info endpoint at `/api/v1/instance`. If it shows your uri, name and email correctly, you are configured correctly. If it shows something like `localhost:4000`, your configuration is probably wrong, unless you are running a local development setup.

  * The common and convenient way for adding HTTPS is by using Nginx as a reverse proxy. You can look at example Nginx configuration in `installation/pleroma.nginx`. If you need TLS/SSL certificates for HTTPS, you can look get some for free with letsencrypt: https://letsencrypt.org/
  The simplest way to obtain and install a certificate is to use [Certbot.](https://certbot.eff.org) Depending on your specific setup, certbot may be able to get a certificate and configure your web server automatically.

  * [Not tested with system reboot yet!] You'll also want to set up Pleroma to be run as a systemd service. Example .service file can be found in `installation/pleroma.service` you can put it in `/etc/systemd/system/`.

## Running

* By default, it listens on port 4000 (TCP), so you can access it on http://localhost:4000/ (if you are on the same machine). In case of an error it will restart automatically.

### Frontends
Pleroma comes with two frontends. The first one, Pleroma FE, can be reached by normally visiting the site. The other one, based on the Mastodon project, can be found by visiting the /web path of your site.

### As systemd service (with provided .service file)
Running `service pleroma start`
Logs can be watched by using `journalctl -fu pleroma.service`

### Standalone/run by other means
Run `mix phx.server` in repository's root, it will output log into stdout/stderr

### Using an upstream proxy for federation

Add the following to your `dev.secret.exs` or `prod.secret.exs` if you want to proxify all http requests that pleroma makes to an upstream proxy server:

    config :pleroma, :http,
      proxy_url: "127.0.0.1:8123"

This is useful for running pleroma inside Tor or i2p.

## Admin Tasks

### Register a User

Run `mix register_user <name> <nickname> <email> <bio>`. The `name` appears on statuses, while the nickname corresponds to the user, e.g. `@nickname@instance.tld`

### Password reset

Run `mix generate_password_reset username` to generate a password reset link that you can then send to the user.

### Moderators

You can make users moderators. They will then be able to delete any post.

Run `mix set_moderator username [true|false]` to make user a moderator or not.

## Troubleshooting

### No incoming federation

Check that you correctly forward the "host" header to backend. It is needed to validate signatures.
