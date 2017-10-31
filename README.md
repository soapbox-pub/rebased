# Pleroma

## About Pleroma

Pleroma is an OStatus-compatible social networking server written in Elixir, compatible with GNU Social and Mastodon. It is high-performance and can run on small devices like a Raspberry Pi.

For clients it supports both the GNU Social API with Qvitter extensions and the Mastodon client API.

Mobile clients that are known to work well:

* Twidere
* Tusky
* Pawoo (Android)
* Subway Tooter
* Amaroq (iOS)

No release has been made yet, but several servers have been online for months already. If you want to run your own server, feel free to contact us at @lain@pleroma.soykaf.com or in our dev chat at https://matrix.heldscal.la/#/room/#pleromafe:matrix.heldscal.la.

## Installation

### Dependencies

* Postgresql version 9.6 or newer
* Elixir version 1.4 or newer
* Build-essential tools

#### Installing dependencies on Debian system
PostgreSQL 9.6 should be available on Debian stable (Jessie) from "main" area. Install it using apt: `apt install postgresql-9.6`. Make sure that older versions are not installed since Debian allows multiple versions to coexist but still runs only one version.

You must install elixir 1.4+ from elixir-lang.org, because Debian repos only have 1.3.x version. You will need to add apt repo to sources.list(.d) and import GPG key. Follow instructions here: https://elixir-lang.org/install.html#unix-and-unix-like (See "Ubuntu or Debian 7"). This should be valid until Debian updates elixir in their repositories. Package you want is named `elixir`, so install it using `apt install elixir`

Elixir will also require `make` and probably other related software for building dependencies - in case you don't have them, get them via `apt install build-essential`

### Preparation

  * You probably want application to run as separte user - so create a new one: `adduser pleroma`, you can login as it via `su pleroma`
  * Clone the git repository into new user's dir (clone as the pleroma user to avoid permissions errors)
  * Again, as new user, install dependencies with `mix deps.get` if it asks you to install "hex" - agree to that.

### Database setup

  * Create a database user and database for pleroma
     * Open psql shell as postgres user: (as root) `su postgres -c psql`
     * Create a new PostgreSQL user:

     ```sql
     \c pleroma_dev
     CREATE user pleroma;
     ALTER user pleroma with encrypted password '<your password>';
     GRANT ALL ON ALL tables IN SCHEMA public TO pleroma;
     GRANT ALL ON ALL sequences IN SCHEMA public TO pleroma;
     ```

     * Create `config/dev.secret.exs` and copy the database settings from `dev.exs` there.
     * Change password in `config/dev.secret.exs`, and change user to `"pleroma"` (line like `username: "postgres"`)
     * Create and update your database with `mix ecto.create && mix ecto.migrate`.

### Some additional configuration

  * You will need to let pleroma instance to know what hostname/url it's running on. _THIS IS THE MOST IMPORTANT STEP. GET THIS WRONG AND YOU'LL HAVE TO RESET YOUR DATABASE_.

    Create the file `config/dev.secret.exs`, add these lines at the end of the file:

    ```elixir
    config :pleroma, Pleroma.Web.Endpoint,
    url: [host: "example.tld", scheme: "https", port: 443]
    ```

    replacing `example.tld` with your (sub)domain

  * You should also setup your site name and admin email address. Look at config.exs for more available options.

    ```elixir
    config :pleroma, :instance,
      name: "My great instance",
      email: "someone@example.com"
    ```

  * The common and convenient way for adding HTTPS is by using Nginx as a reverse proxy. You can look at example Nginx configuration in `installation/pleroma.nginx`. If you need TLS/SSL certificates for HTTPS, you can look get some for free with letsencrypt: https://letsencrypt.org/
  On Debian you can use `certbot` package and command to manage letsencrypt certificates.

  * [Not tested with system reboot yet!] You'll also want to set up Pleroma to be run as a systemd service. Example .service file can be found in `installation/pleroma.service` you can put it in `/etc/systemd/system/`.

## Running

By default, it listens on port 4000 (TCP), so you can access it on http://localhost:4000/ (if you are on the same machine). In case of an error it will restart automatically.

### As systemd service (with provided .service file)
Running `service pleroma start`
Logs can be watched by using `journalctl -fu pleroma.service`

### Standalone/run by other means
Run `mix phx.server` in repository's root, it will output log into stdout/stderr
