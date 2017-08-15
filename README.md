# Pleroma

## Installation

### Dependencies

* Postgresql version 9.5 or newer
* Elixir version 1.4 or newer
* NodeJS LTS 
* Build-essential tools

#### Installing dependencies on Debian system
PostgreSQL 9.6 should be available on debian stable (Jessie) from "main" area. Install it using apt: `apt install postgresql-9.6`. Make sure that older versions are not installed, debian allows multiple versions to coexist but still runs only one version.

You must install elixir 1.4+ from elixir-lang.org, because Debian repos only have 1.3.x version. You will need to add apt repo to sources.list(.d) and import GPG key. Follow instructions here: https://elixir-lang.org/install.html#unix-and-unix-like (See "Ubuntu or Debian 7"). This should be valid until Debian updates elixir in their repositories. Package you want is named `elixir`, so install it using `apt install elixir`

Elixir will also require `make` and probably other related software for building dependencies - in case you don't have them, get them via `apt install build-essential`

NodeJS is available as `nodejs` package on debian. `apt install nodejs`. Debian stable has 4.8.x version. If that does not work, use nodesource's repo https://github.com/nodesource/distributions#deb - version 5.x confirmed to work.

### Preparation

  * You probably want application to run as separte user - so create a new one: `adduser pleroma`, you can login as it via `su pleroma`
  * Clone the git repository into new user's dir (clone as the pleroma user to avoid permissions errors)
  * Again, as new user, install dependencies with `mix deps.get` if it asks you to install "hex" - agree to that.

### Database preparation

  * You'll need to allow password-based authorisation for `postgres` superuser
     * changing default password for superuser is probably a good idea:
        * Open psql shell as postgres user - while being root run `su postgres -c psql`
        * There, enter following: `ALTER USER postgres with encrypted password '<PASSWORD>';` - where <PASSWORD> is just any string, no need to manually encrypt it, postgres will encrypt it automatically for you.
        * Replace password in file `config/dev.exs` with password you supplied in previous step (look for line like `password: "postgres"`)
     
     * edit `/etc/postgresql/9.6/main/pg_hba.conf` (Assuming you have 9.6 version) and change the line:

     ```
     local   all             postgres                                peer
     ```

     to

     ```
     local   all             postgres                                md5
     ```

     don't forget to revert it in the later step so you won't have to enter password when accessing psql console.
  * Create and update your database with `mix ecto.create && mix ecto.migrate`. If it gives errors, try running again, this is a known issue.
  * Undo changes you made in `/etc/postgresql/9.6/main/pg_hba.conf` (replace `md5` with `peer`)
  * You most likely don't want having some application accessing database as superuser, so you need to create separate user for that. Right now it must be done manually (issue #27).
     * Open psql shell as postgres user: (as root) `su postgres -c psql`
     * Create a new PostgreSQL user: 

     ```sql
     \c pleroma_dev
     CREATE user pleroma;
     ALTER user pleroma with encrypted password '<your password>';
     GRANT ALL ON ALL tables IN SCHEMA public TO pleroma;
     GRANT ALL ON ALL sequences IN SCHEMA public TO pleroma;
     ```

     * Again, change password in `config/dev.exs`, and change user to `"pleroma"` (line like `username: "postgres"`)

### Some additional configuration

  * You will need to let pleroma instance to know what hostname/url it's running on.

    In file `config/dev.exs`, add these lines at the end of the file:

    ```elixir
    config :pleroma, Pleroma.Web.Endpoint,
    url: [host: "example.tld", scheme: "https", port: 443] 
    ```

    replacing `example.tld` with your (sub)domain
    
  * The common and convenient way for adding HTTPS is by using nginx as reverse proxy. You can look at example nginx configuration in `installation/pleroma.nginx`. If you need TLS/SSL certificates for HTTPS, you can look get some for free with letsencrypt: https://letsencrypt.org/
  On debian you can use `certbot` package and command to manage letsencrypt certificates.

  * (not tested with reboots yet!) You'll also want to set up Pleroma to be run as a systemd service. Example .service can be found in `installation/pleroma.service` you can put it in `/etc/systemd/system/`.
  Start pleroma by running `service pleroma start`
  Logs can be watched by using `journalctl -fu pleroma.service`

  * Without systemd you can start Pleroma by starting Phoenix endpoint with `mix phx.server`

In any case, it should be available on 4000 port on localhost and proxied to 443 port by nginx.



# Phoenix info

Ready to run in production? Please [check our deployment guides](http://www.phoenixframework.org/docs/deployment).

## Learn more

  * Official website: http://www.phoenixframework.org/
  * Guides: http://phoenixframework.org/docs/overview
  * Docs: https://hexdocs.pm/phoenix
  * Mailing list: http://groups.google.com/group/phoenix-talk
  * Source: https://github.com/phoenixframework/phoenix
