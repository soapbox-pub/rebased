# Installing on Gentoo GNU/Linux
## Installation

This guide will assume that you have administrative rights, either as root or a user with [sudo permissions](https://wiki.gentoo.org/wiki/Sudo). Lines that begin with `#` indicate that they should be run as the superuser. Lines using `$` should be run as the indicated user, e.g. `pleroma$` should be run as the `pleroma` user.

### Configuring your hostname (optional)

If you would like your prompt to permanently include your host/domain, change `/etc/conf.d/hostname` to your hostname. You can reboot or use the `hostname` command to make immediate changes.

### Your make.conf, package.use, and USE flags

The only specific USE flag you should need is the `uuid` flag for `dev-db/postgresql`. Add the following line to any new file in `/etc/portage/package.use`. If you would like a suggested name for the file, either `postgresql` or `pleroma` would do fine, depending on how you like to arrange your package.use flags.

```text
dev-db/postgresql uuid
```

You could opt to add `USE="uuid"` to `/etc/portage/make.conf` if you'd rather set this as a global USE flags, but this flags does unrelated things in other packages, so keep that in mind if you elect to do so.

Double check your compiler flags in `/etc/portage/make.conf`. If you require any special compilation flags or would like to set up remote builds, now is the time to do so. Be sure that your CFLAGS and MAKEOPTS make sense for the platform you are using. It is not recommended to use above `-O2` or risky optimization flags for a production server.

### Installing a cron daemon

Gentoo quite pointedly does not come with a cron daemon installed, and as such it is recommended you install one to automate certbot renewals and to allow other system administration tasks to be run automatically. Gentoo has [a whole wide world of cron options](https://wiki.gentoo.org/wiki/Cron) but if you just want A Cron That Works, `emerge --ask virtual/cron` will install the default cron implementation (probably cronie) which will work just fine. For the purpouses of this guide, we will be doing just that.

### Required ebuilds

* `dev-db/postgresql`
* `dev-lang/elixir`
* `dev-vcs/git`

#### Optional ebuilds used in this guide

* `www-servers/nginx` (preferred, example configs for other reverse proxies can be found in the repo)
* `app-crypt/certbot` (or any other ACME client for Let’s Encrypt certificates)
* `app-crypt/certbot-nginx` (nginx certbot plugin that allows use of the all-powerful `--nginx` flag on certbot)

### Prepare the system

* First ensure that you have the latest copy of the portage ebuilds if you have not synced them yet:

```shell
 # emaint sync -a
```

* Emerge all required the required and suggested software in one go:

```shell
 # emerge --ask dev-db/postgresql dev-lang/elixir dev-vcs/git www-servers/nginx app-crypt/certbot app-crypt/certbot-nginx
```

If you would not like to install the optional packages, remove them from this line. 

If you're running this from a low-powered virtual machine, it should work though it will take some time. There were no issues on a VPS with a single core and 1GB of RAM; if you are using an even more limited device and run into issues, you can try creating a swapfile or use a more powerful machine running Gentoo to [cross build](https://wiki.gentoo.org/wiki/Cross_build_environment). If you have a wait ahead of you, now would be a good time to take a break, strech a bit, refresh your beverage of choice and/or get a snack, and reply to Arch users' posts with "I use Gentoo btw" as we do.

### Install PostgreSQL

[Gentoo  Wiki article](https://wiki.gentoo.org/wiki/PostgreSQL) as well as [PostgreSQL QuickStart](https://wiki.gentoo.org/wiki/PostgreSQL/QuickStart) might be worth a quick glance, as the way Gentoo handles postgres is slightly unusual, with built in capability to have two different databases running for testing and live or whatever other purpouse. While it is still straightforward to install, it does mean that the version numbers used in this guide might change for future updates, so keep an eye out for the output you get from `emerge` to ensure you are using the correct ones.

* Install postgresql if you have not done so already:

```shell
 # emerge --ask dev-db/postgresql
```

Ensure that `/etc/conf.d/postgresql-11` has the encoding you want (it defaults to UTF8 which is probably what you want) and make any adjustments to the data directory if you find it necessary. Be sure to adjust the number at the end depending on what version of postgres you actually installed.

* Initialize the database cluster

The output from emerging postgresql should give you a command for initializing the postgres database. The default slot should be indicated in this command, ensure that it matches the command below.

```shell
 # emerge --config dev-db/postgresql:11
```

* Start postgres and enable the system service
 
```shell
 # /etc/init.d/postgresql-11 start
 # rc-update add postgresql-11 default
 ```
 
### A note on licenses, the AGPL, and deployment procedures

If you do not plan to make any modifications to your Pleroma instance, cloning directly from the main repo will get you what you need. However, if you plan on doing any contributions to upstream development, making changes or modifications to your instance, making custom themes, or want to play around--and let's be honest here, if you're using Gentoo that is most likely you--you will save yourself a lot of headache later if you take the time right now to fork the Pleroma repo and use that in the following section.

Not only does this make it much easier to deploy changes you make, as you can commit and pull from upstream and all that good stuff from the comfort of your local machine then simply `git pull` on your instance server when you're ready to deploy, it also ensures you are compliant with the Affero General Public Licence that Pleroma is licenced under, which stipulates that all network services provided with modified AGPL code must publish their changes on a publicly available internet service and for free. It also makes it much easier to ask for help from and provide help to your fellow Pleroma admins if your public repo always reflects what you are running because it is part of your deployment procedure.

### Install PleromaBE

* Add a new system user for the Pleroma service and set up default directories:

Remove `,wheel` if you do not want this user to be able to use `sudo`, however note that being able to `sudo` as the `pleroma` user will make finishing the insallation and common maintenence tasks somewhat easier:

```shell
 # useradd -m -G users,wheel -s /bin/bash pleroma
```

Optional: If you are using sudo, review your sudo setup to ensure it works for you. The `/etc/sudoers` file has a lot of options and examples to help you, and [the Gentoo sudo guide](https://wiki.gentoo.org/wiki/Sudo) has more information. Finishing this installation will be somewhat easier if you have a way to sudo from the `pleroma` user, but it might be best to not allow that user to sudo during normal operation, and as such there will be a reminder at the end of this guide to double check if you would like to lock down the `pleroma` user after initial setup.

**Note**: To execute a single command as the Pleroma system user, use `sudo -Hu pleroma command`. You can also switch to a shell by using `sudo -Hu pleroma $SHELL`. If you don't have or want `sudo` or would like to use the system as the `pleroma` user for instance maintenance tasks, you can simply use `su - pleroma` to switch to the `pleroma` user.

* Git clone the PleromaBE repository and make the Pleroma user the owner of the directory:

It is highly recommended you use your own fork for the `https://path/to/repo` part below, however if you foolishly decide to forego using your own fork, the primary repo `https://git.pleroma.social/pleroma/pleroma` will work here.

```shell
 pleroma$ cd ~
 pleroma$ git clone -b stable https://path/to/repo
```

* Change to the new directory:

```shell
pleroma$ cd ~/pleroma
```

* Install the dependencies for Pleroma and answer with `yes` if it asks you to install `Hex`:

```shell
pleroma$ mix deps.get
```

* Generate the configuration:

```shell
pleroma$ mix pleroma.instance gen
```

  * Answer with `yes` if it asks you to install `rebar3`.

  * This part precompiles some parts of Pleroma, so it might take a few moments

  * After that it will ask you a few questions about your instance and generates a configuration file in `config/generated_config.exs`.

  * Spend some time with `generated_config.exs` to ensure that everything is in order. If you plan on using an S3-compatible service to store your local media, that can be done here. You will likely mostly be using `prod.secret.exs` for a production instance, however if you would like to set up a development environment, make a copy to `dev.secret.exs` and adjust settings as needed as well.

```shell
pleroma$ mv config/generated_config.exs config/prod.secret.exs
```

* The previous command creates also the file `config/setup_db.psql`, with which you can create the database. Ensure that it is using the correct database name on the `CREATE DATABASE` and the `\c` lines, then run the postgres script:

```shell
pleroma$ sudo -Hu postgres psql -f config/setup_db.psql
```

* Now run the database migration:

```shell
pleroma$ MIX_ENV=prod mix ecto.migrate
```

* Now you can start Pleroma already

```shell
pleroma$ MIX_ENV=prod mix phx.server
```

It probably won't work over the public internet quite yet, however, as we still need to set up a web servere to proxy to the pleroma application, as well as configure SSL.

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
 # cp /home/pleroma/pleroma/installation/pleroma.nginx /etc/nginx/sites-available/
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

If you would like to use other webservers or proxies, there are example configurations for some popular alternatives in `/home/pleroma/pleroma/installation/`. You can, of course, check out [the Gentoo wiki](https://wiki.gentoo.org) for more information on installing and configuring said alternatives.

#### Create the uploads folder

Even if you are using S3, Pleroma needs someplace to store media posted on your instance. If you are using the `/home/pleroma/pleroma` root folder suggested by this guide, simply:

```shell
 pleroma$ mkdir -p ~/pleroma/uploads
 ```

#### init.d service

* Copy example service file

```shell
 # cp /home/pleroma/pleroma/installation/init.d/pleroma /etc/init.d/
```

* Be sure to take a look at this service file and make sure that all paths fit your installation

* Enable and start `pleroma`:

```shell
 # rc-update add pleroma default
 # /etc/init.d/pleroma start
```

#### Create your first user

If your instance is up and running, you can create your first user with administrative rights with the following task:

```shell
pleroma$ MIX_ENV=prod mix pleroma.user new <username> <your@emailaddress> --admin
```

#### Privilege cleanup

If you opted to allow sudo for the `pleroma` user but would like to remove the ability for greater security, now might be a good time to edit `/etc/sudoers` and/or change the groups the `pleroma` user belongs to. Be sure to restart the pleroma service afterwards to ensure it picks up on the changes.

#### Further reading

* [Backup your instance](../administration/backup.md)
* [Hardening your instance](../configuration/hardening.md)
* [How to activate mediaproxy](../configuration/howto_mediaproxy.md)
* [Updating your instance](../administration/updating.md)

## Questions

Questions about the installation or didn’t it work as it should be, ask in [#pleroma:matrix.org](https://matrix.heldscal.la/#/room/#freenode_#pleroma:matrix.org) or IRC Channel **#pleroma** on **Freenode**.
