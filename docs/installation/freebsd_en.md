# Installing on FreeBSD 

This document was written for FreeBSD 12.1, but should be trivially trailerable to future releases.
Additionally, this guide document can be modified to 

## Required software 

This assumes the target system has `pkg(8)`.

`# pkg install elixir postgresql12-server postgresql12-client postgresql12-contrib git-lite sudo nginx gmake acme.sh`

Copy the rc.d scripts to the right directory:

Setup the required services to automatically start at boot, using `sysrc(8)`.

```
# sysrc nginx_enable=YES
# sysrc postgresql_enable=YES
```

## Initialize postgres

```
# service postgresql initdb
# service postgresql start
```

## Configuring Pleroma

Create a user for Pleroma:

```
# pw add user pleroma -m
# echo 'export LC_ALL="en_US.UTF-8"' >> /home/pleroma/.profile
# su -l pleroma
```

Clone the repository:

```
$ cd $HOME # Should be the same as /home/pleroma
$ git clone -b stable https://git.pleroma.social/pleroma/pleroma.git
```

Configure Pleroma. Note that you need a domain name at this point:

```
$ cd /home/pleroma/pleroma
$ mix deps.get
$ mix pleroma.instance gen # You will be asked a few questions here.
$ cp config/generated_config.exs config/prod.secret.exs # The default values should be sufficient but you should edit it and check that everything seems OK.
```

Since Postgres is configured, we can now initialize the database. There should
now be a file in `config/setup_db.psql` that makes this easier. Edit it, and
*change the password* to a password of your choice. Make sure it is secure, since
it'll be protecting your database. As root, you can now initialize the database:

```
# cd /home/pleroma/pleroma
# sudo -Hu postgres -g postgres psql -f config/setup_db.psql
```

Postgres allows connections from all users without a password by default. To
fix this, edit `/var/db/postgres/data12/pg_hba.conf`. Change every `trust` to
`password`.

Once this is done, restart Postgres with `# service postgresql restart`.

Run the database migrations.

Back as the pleroma user, you will need to do this whenever you update with `git pull`:

```
# su -l pleroma
$ cd /home/pleroma/pleroma
$ MIX_ENV=prod mix ecto.migrate
```

## Configuring nginx

Install the example configuration file
`/home/pleroma/pleroma/installation/pleroma.nginx` to
`/usr/local/etc/nginx/nginx.conf`.

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
`/etc/ssl/example.tld/fullchain`.
* Change `ssl_certificate_key` to `/etc/ssl/example.tld/key`.
* Change `example.tld` to your instance's domain name.

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
# service nginx start
```

It should now be possible to issue a cert (replace `example.com`
with your domain name):

```
$ sudo -Hu nginx -g nginx acme.sh --issue -d example.com --stateless
$ acme.sh --install-cert -d example.com \
	--key-file       /path/to/keyfile/in/nginx/key.pem  \
	--fullchain-file /path/to/fullchain/nginx/cert.pem \
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

## Creating a startup script for Pleroma

Pleroma will need to compile when it initially starts, which typically takes a longer
period of time. Therefore, it is good practice to initially run pleroma from the
command-line before utilizing the rc.d script. That is done as follows:

```
# su -l pleroma
$ cd $HOME/pleroma
$ MIX_ENV=prod mix phx.server
```

Copy the startup script to the correct location and make sure it's executable:

```
# cp /home/pleroma/pleroma/installation/freebsd/rc.d/pleroma /usr/local/etc/rc.d/pleroma
# chmod +x /etc/rc.d/pleroma
```

Add the following to `/etc/rc.conf`:

```
pleroma=YES
pleroma_home="/home/pleroma"
pleroma_user="pleroma"
```

Run `# /etc/rc.d/pleroma start` to start Pleroma.

## Conclusion

Restart nginx with `# /etc/rc.d/nginx restart` and you should be up and running.

If you need further help, contact niaa on freenode.

Make sure your time is in sync, or other instances will receive your posts with
incorrect timestamps. You should have ntpd running.

#### Further reading

{! backend/installation/further_reading.include !}

## Questions

Questions about the installation or didn’t it work as it should be, ask in [#pleroma:matrix.org](https://matrix.heldscal.la/#/room/#freenode_#pleroma:matrix.org) or IRC Channel **#pleroma** on **Freenode**.
