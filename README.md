# Pleroma

**Note**: This readme as well as complete documentation is also available at <https://docs-develop.pleroma.social>

## About Pleroma

Pleroma is a microblogging server software that can federate (= exchange messages with) other servers that support the same federation standards (OStatus and ActivityPub). What that means is that you can host a server for yourself or your friends and stay in control of your online identity, but still exchange messages with people on larger servers. Pleroma will federate with all servers that implement either OStatus or ActivityPub, like Friendica, GNU Social, Hubzilla, Mastodon, Misskey, Peertube, and Pixelfed.

Pleroma is written in Elixir, high-performance and can run on small devices like a Raspberry Pi.

For clients it supports the [Mastodon client API](https://docs.joinmastodon.org/api/guidelines/) with Pleroma extensions (see "Pleroma's APIs and Mastodon API extensions" section on <https://docs-develop.pleroma.social>).

- [Client Applications for Pleroma](https://docs-develop.pleroma.social/clients.html)

If you want to run your own server, feel free to contact us at @lain@pleroma.soykaf.com or in our dev chat at #pleroma on freenode or via matrix at <https://matrix.heldscal.la/#/room/#freenode_#pleroma:matrix.org>.

## Installation
**Note:** The guide below may be outdated and in most cases shouldn't be used. Instead check out our [wiki](https://docs.pleroma.social) for platform-specific installation instructions, most likely [Installing on Linux using OTP releases](https://docs.pleroma.social/otp_en.html) is the guide you need.

### OS/Distro packages
Currently Pleroma is not packaged by any OS/Distros, but feel free to reach out to us at [#pleroma-dev on freenode](https://webchat.freenode.net/?channels=%23pleroma-dev) or via matrix at <https://matrix.heldscal.la/#/room/#freenode_#pleroma-dev:matrix.org> for assistance. If you want to change default options in your Pleroma package, please **discuss it with us first**.

### Docker
While we don’t provide docker files, other people have written very good ones. Take a look at <https://github.com/angristan/docker-pleroma> or <https://glitch.sh/sn0w/pleroma-docker>.

### Dependencies

* Postgresql version 9.6 or newer
* Elixir version 1.7 or newer. If your distribution only has an old version available, check [Elixir’s install page](https://elixir-lang.org/install.html) or use a tool like [asdf](https://github.com/asdf-vm/asdf).
* Build-essential tools

### Configuration

* Run `mix deps.get` to install elixir dependencies.
* Run `mix pleroma.instance gen`. This will ask you questions about your instance and generate a configuration file in `config/generated_config.exs`. Check that and copy it to either `config/dev.secret.exs` or `config/prod.secret.exs`. It will also create a `config/setup_db.psql`, which you should run as the PostgreSQL superuser (i.e., `sudo -u postgres psql -f config/setup_db.psql`). It will create the database, user, and password you gave `mix pleroma.gen.instance` earlier, as well as set up the necessary extensions in the database. PostgreSQL superuser privileges are only needed for this step.
* For these next steps, the default will be to run pleroma using the dev configuration file, `config/dev.secret.exs`. To run them using the prod config file, prefix each command at the shell with `MIX_ENV=prod`. For example: `MIX_ENV=prod mix phx.server`. Documentation for the config can be found at [`docs/config.md`](docs/config.md) in the repository, or at the "Configuration" page on <https://docs-develop.pleroma.social/config.html>
* Run `mix ecto.migrate` to run the database migrations. You will have to do this again after certain updates.
* You can check if your instance is configured correctly by running it with `mix phx.server` and checking the instance info endpoint at `/api/v1/instance`. If it shows your uri, name and email correctly, you are configured correctly. If it shows something like `localhost:4000`, your configuration is probably wrong, unless you are running a local development setup.
* The common and convenient way for adding HTTPS is by using Nginx as a reverse proxy. You can look at example Nginx configuration in `installation/pleroma.nginx`. If you need TLS/SSL certificates for HTTPS, you can look get some for free with letsencrypt: <https://letsencrypt.org/>. The simplest way to obtain and install a certificate is to use [Certbot.](https://certbot.eff.org) Depending on your specific setup, certbot may be able to get a certificate and configure your web server automatically.

## Running

* By default, it listens on port 4000 (TCP), so you can access it on <http://localhost:4000/> (if you are on the same machine). In case of an error it will restart automatically.

### Frontends

Pleroma comes with two frontends. The first one, Pleroma FE, can be reached by normally visiting the site. The other one, based on the Mastodon project, can be found by visiting the /web path of your site.

### As systemd service (with provided .service file)

Example .service file can be found in `installation/pleroma.service`. Copy this to `/etc/systemd/system/`. Running `systemctl enable --now pleroma.service` will run Pleroma and enable startup on boot. Logs can be watched by using `journalctl -fu pleroma.service`.

### As OpenRC service (with provided RC file)

Copy `installation/init.d/pleroma` to `/etc/init.d/pleroma`. You can add it to the services ran by default with: `rc-update add pleroma`

### Standalone/run by other means

Run `mix phx.server` in repository’s root, it will output log into stdout/stderr.

### Using an upstream proxy for federation

Add the following to your `dev.secret.exs` or `prod.secret.exs` if you want to proxify all http requests that Pleroma makes to an upstream proxy server:

```elixir
config :pleroma, :http,
  proxy_url: "127.0.0.1:8123"
```

This is useful for running Pleroma inside Tor or I2P.

## Customization and contribution

The [Pleroma Documentation](https://docs-develop.pleroma.social) offers manuals and guides on how to further customize your instance to your liking and how you can contribute to the project.

## Troubleshooting

### No incoming federation

Check that you correctly forward the `host` header to the backend. It is needed to validate signatures.
