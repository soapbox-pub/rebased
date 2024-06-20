# Installing on NetBSD

{! backend/installation/generic_dependencies.include !}

# Installation options

Currently there are two options available for NetBSD: manual installation (from source) or using experimental package from [pkgsrc-wip](https://github.com/NetBSD/pkgsrc-wip/tree/master/pleroma).

WIP package can be installed via pkgsrc and can be crosscompiled for easier binary distribution. Source installation most probably will be restricted to a single machine.

## pkgsrc installation

WIP package creates Mix.Release (similar to how Docker images are built) but doesn't bundle Erlang runtime, listing it as a dependency instead. This allows for easier and more modular installations, especially on weaker machines. Currently this method also does not support all features of `pleroma_ctl` command (like changing installation type or managing frontends) as NetBSD is not yet a supported binary flavour of Pleroma's CI.

In any case, you can install it the same way as any other `pkgsrc-wip` package:

```
cd /usr/pkgsrc
git clone --depth 1 git://wip.pkgsrc.org/pkgsrc-wip.git wip
cp -rf wip/pleroma www
cp -rf wip/libvips graphics
cd /usr/pkgsrc/www/pleroma
bmake && bmake install
```

Use `bmake package` to create a binary package. This can come especially handy if you're targeting embedded or low-power systems and are crosscompiling on a more powerful machine.

> Note: Elixir has [endianness bug](https://github.com/elixir-lang/elixir/issues/2785) which requires it to be compiled on a machine with the same endianness. In other words, package crosscompiled on amd64 (little endian) won't work on powerpc or sparc machines (big endian). While _in theory™_ nothing catastrophic should happen, one can see that for example regexes won't work properly. Some distributions just strip this warning away, so it doesn't bother the users... anyway, you've been warned.

## Source installation

pkgin should have been installed by the NetBSD installer if you selected
the right options. If it isn't installed, install it using `pkg_add`.

Note that `postgresql11-contrib` is needed for the Postgres extensions
Pleroma uses.

> Note: you can use modern versions of PostgreSQL. In this case, just use `postgresql16-contrib` and so on.

The `mksh` shell is needed to run the Elixir `mix` script.

`# pkgin install acmesh elixir git-base git-docs mksh nginx postgresql11-server postgresql11-client postgresql11-contrib sudo ffmpeg4 ImageMagick`

You can also build these packages using pkgsrc:
```
databases/postgresql11-contrib
databases/postgresql11-client
databases/postgresql11-server
devel/git-base
devel/git-docs
devel/cmake
lang/elixir
security/acmesh
security/sudo
shells/mksh
www/nginx
```

Create a user for Pleroma:

```
# groupadd pleroma
# useradd -d /home/pleroma -m -g pleroma -s /usr/pkg/bin/mksh pleroma
# echo 'export LC_ALL="en_GB.UTF-8"' >> /home/pleroma/.profile
# su -l pleroma -c $SHELL
```

Clone the repository:

```
$ cd /home/pleroma
$ git clone -b stable https://git.pleroma.social/pleroma/pleroma.git
```

Get deps and compile:

```
$ cd /home/pleroma/pleroma
$ export MIX_ENV=prod
$ mix deps.get
$ mix compile
```

## Install media / graphics packages (optional, see [`docs/installation/optional/media_graphics_packages.md`](../installation/optional/media_graphics_packages.md))

`# pkgin install ImageMagick ffmpeg4 p5-Image-ExifTool`

or via pkgsrc:

```
graphics/p5-Image-ExifTool
graphics/ImageMagick
multimedia/ffmpeg4
```

# Configuration

## Understanding $PREFIX

From now on, you may encounter `$PREFIX` variable in the paths. This variable indicates your current local pkgsrc prefix. Usually it's `/usr/pkg` unless you configured it otherwise. Translating to pkgsrc's lingo, it's called `LOCALBASE`, which essentially means the same this. You may want to set it up for your local shell session (this uses `mksh` which should already be installed as one of the required dependencies):

```
$ export PREFIX=$(pkg_info -Q LOCALBASE mksh)
$ echo $PREFIX
/usr/pkg
```

## Setting up your instance

Now, you need to configure your instance. During this initial configuration, you will be asked some questions about your server. You will need a domain name at this point; it doesn't have to be deployed, but changing it later will be very cumbersome.

If you've installed via pkgsrc, `pleroma_ctl` should already be in your `PATH`; if you've installed from source, it's located at `/home/pleroma/pleroma/release/bin/pleroma_ctl`.

```
$ su -l pleroma
$ pleroma_ctl instance gen --output $PREFIX/etc/pleroma/config.exs --output-psql /tmp/setup_db.psql
```

During installation, you will be asked about static and upload directories. Don't forget to create them and update permissions:

```
mkdir -p /var/lib/pleroma/uploads
chown -R pleroma:pleroma /var/lib/pleroma
```

## Setting up the database

First, run `# /etc/rc.d/pgsql start`. Then, `$ sudo -Hu pgsql -g pgsql createdb`.

We can now initialize the database. You'll need to edit generated SQL file from the previous step. It's located at `/tmp/setup_db.psql`.

Edit this file, and *change the password* to a password of your choice. Make sure it is secure, since
it'll be protecting your database. Now initialize the database:

```
$ sudo -Hu pgsql -g pgsql psql -f /tmp/setup_db.psql
```

Postgres allows connections from all users without a password by default. To
fix this, edit `$PREFIX/pgsql/data/pg_hba.conf`. Change every `trust` to
`password`.

Once this is done, restart Postgres with `# /etc/rc.d/pgsql restart`.

Run the database migrations.

### pkgsrc installation

```
pleroma_ctl migrate
```

### Source installation

You will need to do this whenever you update with `git pull`:

```
$ cd /home/pleroma/pleroma
$ MIX_ENV=prod mix ecto.migrate
```

## Configuring nginx

Install the example configuration file
(`$PREFIX/share/examples/pleroma/pleroma.nginx` or `/home/pleroma/pleroma/installation/pleroma.nginx`) to
`$PREFIX/etc/nginx.conf`.

Note that it will need to be wrapped in a `http {}` block. You should add
settings for the nginx daemon outside of the http block, for example:

```
user                    nginx  nginx;
error_log               /var/log/nginx/error.log;
worker_processes        4;

events {
}
```

Edit the defaults:

* Change `ssl_certificate` and `ssl_trusted_certificate` to
`/etc/nginx/tls/fullchain`.
* Change `ssl_certificate_key` to `/etc/nginx/tls/key`.
* Change `example.tld` to your instance's domain name.

### (Strongly recommended) serve media on another domain

Refer to the [Hardening your instance](../configuration/hardening.md) document on how to serve media on another domain. We STRONGLY RECOMMEND you to do this to minimize attack vectors.

## Configuring acme.sh

We'll be using acme.sh in Stateless Mode for TLS certificate renewal.

First, get your account fingerprint:

```
$ sudo -Hu nginx -g nginx acme.sh --register-account
```

You need to add the following to your nginx configuration for the server
running on port 80:

```
  location ~ ^/\.well-known/acme-challenge/([-_a-zA-Z0-9]+)$ {
    default_type text/plain;
    return 200 "$1.6fXAG9VyG0IahirPEU2ZerUtItW2DHzDzD9wZaEKpqd";
  }
```

Replace the string after after `$1.` with your fingerprint.

Start nginx:

```
# /etc/rc.d/nginx start
```

It should now be possible to issue a cert (replace `example.com`
with your domain name):

```
$ sudo -Hu nginx -g nginx acme.sh --issue -d example.com --stateless
```

Let's add auto-renewal to `/etc/daily.local`
(replace `example.com` with your domain):

```
/usr/pkg/bin/sudo -Hu nginx -g nginx \
    /usr/pkg/sbin/acme.sh -r \
    -d example.com \
    --cert-file /etc/nginx/tls/cert \
    --key-file /etc/nginx/tls/key \
    --ca-file /etc/nginx/tls/ca \
    --fullchain-file /etc/nginx/tls/fullchain \
    --stateless
```

## Autostart

For properly functioning instance, you will need pleroma (backend service), nginx (reverse proxy) and postgresql (database) services running. There's no requirement for them to reside on the same machine, but you have to provide autostart for each of them.

### nginx
```
# cp $PREFIX/share/examples/rc.d/nginx /etc/rc.d
# echo "nginx=YES" >> /etc/rc.conf
```

### postgresql

```
# cp $PREFIX/share/examples/rc.d/pgsql /etc/rc.d
# echo "pgsql=YES" >> /etc/rc.conf
```

### pleroma

First, copy the script (pkgsrc variant)
```
# cp $PREFIX/share/examples/pleroma/pleroma.rc /etc/rc.d/pleroma
```

or source variant
```
# cp /home/pleroma/pleroma/installation/netbsd/rc.d/pleroma /etc/rc.d/pleroma
# chmod +x /etc/rc.d/pleroma
```

Then, add the following to `/etc/rc.conf`:

```
pleroma=YES
```

## Conclusion

Run `# /etc/rc.d/pleroma start` to start Pleroma.
Restart nginx with `# /etc/rc.d/nginx restart` and you should be up and running.

Make sure your time is in sync, or other instances will receive your posts with
incorrect timestamps. You should have ntpd running.

## Instances running NetBSD

* <https://catgirl.science>

#### Further reading

{! backend/installation/further_reading.include !}

## Questions

Questions about the installation or didn’t it work as it should be, ask in [#pleroma:libera.chat](https://matrix.to/#/#pleroma:libera.chat) via Matrix or **#pleroma** on **libera.chat** via IRC.
