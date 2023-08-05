# Packaged install on Gentoo Linux

{! backend/installation/otp_vs_from_source.include !}

This guide covers installation via Gentoo provided packaging. A [manual installation guide for gentoo](./gentoo_en.md) is also available.

## Installation

This guide will assume that you have administrative rights, either as root or a user with [sudo permissions](https://wiki.gentoo.org/wiki/Sudo). Lines that begin with `#` indicate that they should be run as the superuser. Lines using `$` should be run as the indicated user, e.g. `pleroma$` should be run as the `pleroma` user.

{! backend/installation/generic_dependencies.include !}

### Installing a cron daemon

Gentoo quite pointedly does not come with a cron daemon installed, and as such it is recommended you install one to automate certbot renewals and to allow other system administration tasks to be run automatically. Gentoo has [a whole wide world of cron options](https://wiki.gentoo.org/wiki/Cron) but if you just want A Cron That Works, `emerge --ask virtual/cron` will install the default cron implementation (probably cronie) which will work just fine. For the purpouses of this guide, we will be doing just that.

### Required ebuilds

* `www-apps/pleroma`

#### Optional ebuilds used in this guide

* `www-servers/nginx` (preferred, example configs for other reverse proxies can be found in the repo)
* `app-crypt/certbot` (or any other ACME client for Let’s Encrypt certificates)
* `app-crypt/certbot-nginx` (nginx certbot plugin that allows use of the all-powerful `--nginx` flag on certbot)
* `media-gfx/imagemagick`
* `media-video/ffmpeg`
* `media-libs/exiftool`

### Prepare the system

* If you haven't yet done so, add the [Gentoo User Repository (GURU)](https://wiki.gentoo.org/wiki/Project:GURU), where the `www-apps/pleroma` ebuild currently lives at:
```shell
 # eselect repository enable guru
```

* Ensure that you have the latest copy of the Gentoo and GURU ebuilds if you have not synced them yet:

```shell
 # emaint sync -a
```


* Emerge all required the required and suggested software in one go:

```shell
 # emerge --ask www-apps/pleroma www-servers/nginx app-crypt/certbot app-crypt/certbot-nginx
```

If you would not like to install the optional packages, remove them from this line.

If you're running this from a low-powered virtual machine, it should work though it will take some time. There were no issues on a VPS with a single core and 1GB of RAM; if you are using an even more limited device and run into issues, you can try creating a swapfile or use a more powerful machine running Gentoo to [cross build](https://wiki.gentoo.org/wiki/Cross_build_environment). If you have a wait ahead of you, now would be a good time to take a break, strech a bit, refresh your beverage of choice and/or get a snack, and reply to Arch users' posts with "I use Gentoo btw" as we do.

### Setup PostgreSQL

[Gentoo  Wiki article](https://wiki.gentoo.org/wiki/PostgreSQL) as well as [PostgreSQL QuickStart](https://wiki.gentoo.org/wiki/PostgreSQL/QuickStart) might be worth a quick glance, as the way Gentoo handles postgres is slightly unusual, with built in capability to have two different databases running for testing and live or whatever other purpouse. While it is still straightforward to install, it does mean that the version numbers used in this guide might change for future updates, so keep an eye out for the output you get from `emerge` to ensure you are using the correct ones.

* Initialize the database cluster

The output from emerging postgresql should give you a command for initializing the postgres database. The default slot should be indicated in this command, ensure that it matches the command below.

```shell
 # emerge --config dev-db/postgresql:11
```

### Install media / graphics packages (optional)

See [Optional software packages needed for specific functionality](optional/media_graphics_packages.md) for details.

```shell
# emerge --ask media-video/ffmpeg media-gfx/imagemagick media-libs/exiftool
```

### Setup PleromaBE

* Generate the configuration:

```shell
 # pleroma_ctl instance gen --output /etc/pleroma/config.exs --output-psql /tmp/setup_db.psql"
```

* Create the PostgreSQL database

```shell
 # sudo -u postgres -s $SHELL -lc "psql -f /tmp/setup_db.psql"
```

* Now run the database migration:

```shell
 # pleroma_ctl migrate
```

* Optional: If you have installed RUM indexes (`dev-db/rum`) you also need to run:
```
 # sudo -Hu pleroma "pleroma_ctl migrate --migrations-path priv/repo/optional_migrations/rum_indexing/"
```

* Now you can start Pleroma already and add it in the default runlevel

```shell
 # rc-service pleroma start
 # rc-update add pleroma default
```

It probably won't work over the public internet quite yet, however, as we still need to set up a web server to proxy to the pleroma application, as well as configure SSL.

### Finalize installation

Assuming you want to open your newly installed federated social network to, well, the federation, you should run nginx or some other webserver/proxy in front of Pleroma. It is also a good idea to set up Pleroma to run as a system service.

#### Nginx

* Install nginx, if not already done:

```shell
 # emerge --ask www-servers/nginx
```

* Create directories for available and enabled sites:

```shell
 # mkdir -p /etc/nginx/sites-{available,enabled}
```

* Append the following line at the end of the `http` block in `/etc/nginx/nginx.conf`:

```Nginx
include sites-enabled/*;
```

* Setup your SSL cert, using your method of choice or certbot. If using certbot, install it if you haven't already:

```shell
 # emerge --ask app-crypt/certbot app-crypt/certbot-nginx
```

and then set it up:

```shell
 # mkdir -p /var/lib/letsencrypt/
 # certbot certonly --email <your@emailaddress> -d <yourdomain> --standalone
```

If that doesn't work the first time, add `--dry-run` to further attempts to avoid being ratelimited as you identify the issue, and do not remove it until the dry run succeeds. If that doesn’t work, make sure, that nginx is not already running. If it still doesn’t work, try setting up nginx first (change ssl “on” to “off” and try again). Often the answer to issues with certbot is to use the `--nginx` flag once you have nginx up and running.

If you are using any additional subdomains, such as for a media proxy, you can re-run the same command with the subdomain in question. When it comes time to renew later, you will not need to run multiple times for each domain, one renew will handle it.

---

* Copy the example nginx configuration and activate it:

```shell
 # cp /opt/pleroma/installation/pleroma.nginx /etc/nginx/sites-available/
 # ln -s /etc/nginx/sites-available/pleroma.nginx /etc/nginx/sites-enabled/pleroma.nginx
```

* Take some time to ensure that your nginx config is correct

Replace all instances of `example.tld` with your instance's public URL. If for whatever reason you made changes to the port that your pleroma app runs on, be sure that is reflected in your configuration.

Pay special attention to the line that begins with `ssl_ecdh_curve`. It is stongly advised to comment that line out so that OpenSSL will use its full capabilities, and it is also possible you are running OpenSSL 1.0.2 necessitating that you do this.

* Enable and start nginx:

```shell
 # rc-update add nginx default
 # /etc/init.d/nginx start
```

If you are using certbot, it is HIGHLY recommend you set up a cron job that renews your certificate, and that you install the suggested `certbot-nginx` plugin. If you don't do these things, you only have yourself to blame when your instance breaks suddenly because you forgot about it.

First, ensure that the command you will be installing into your crontab works.

```shell
 # /usr/bin/certbot renew --nginx
```

Assuming not much time has passed since you got certbot working a few steps ago, you should get a message for all domains you installed certificates for saying `Cert not yet due for renewal`.

Now, run crontab as a superuser with `crontab -e` or `sudo crontab -e` as appropriate, and add the following line to your cron:

```cron
0 0 1 * * /usr/bin/certbot renew --nginx
```

This will run certbot on the first of the month at midnight. If you'd rather run more frequently, it's not a bad idea, feel free to go for it.

#### Other webserver/proxies

If you would like to use other webservers or proxies, there are example configurations for some popular alternatives in `/opt/pleroma/installation/`. You can, of course, check out [the Gentoo wiki](https://wiki.gentoo.org) for more information on installing and configuring said alternatives.

#### Create your first user

If your instance is up and running, you can create your first user with administrative rights with the following task:

```shell
pleroma$ pleroma_ctl user new <username> <your@emailaddress> --admin
```

#### Further reading

{! backend/installation/further_reading.include !}

## Questions

Questions about the installation or didn’t it work as it should be, ask in [#pleroma:libera.chat](https://matrix.to/#/#pleroma:libera.chat) via Matrix or **#pleroma** on **libera.chat** via IRC.
