# Installing on Linux using OTP releases

## Pre-requisites
* A machine running Linux with GNU (e.g. Debian, Ubuntu) or musl (e.g. Alpine) libc and `x86_64`, `aarch64` or `armv7l` CPU, you have root access to. If you are not sure if it's compatible see [Detecting flavour section](#detecting-flavour) below
* A (sub)domain pointed to the machine

You will be running commands as root. If you aren't root already, please elevate your priviledges by executing `sudo su`/`su`.

While in theory OTP releases are possbile to install on any compatible machine, for the sake of simplicity this guide focuses only on Debian/Ubuntu/Alpine.

### Detecting flavour

Paste the following into the shell:
```sh
arch="$(uname -m)";if [ "$arch" = "x86_64" ];then arch="amd64";elif [ "$arch" = "armv7l" ];then arch="arm";elif [ "$arch" = "aarch64" ];then arch="arm64";else echo "Unsupported arch: $arch">&2;fi;if getconf GNU_LIBC_VERSION>/dev/null;then libc_postfix="";elif [ "$(ldd 2>&1|head -c 9)" = "musl libc" ];then libc_postfix="-musl";elif [ "$(find /lib/libc.musl*|wc -l)" ];then libc_postfix="-musl";else echo "Unsupported libc">&2;fi;echo "$arch$libc_postfix"
```

If your platform is supported the output will contain the flavour string, you will need it later. If not, this just means that we don't build releases for your platform, you can still try installing from source.

### Installing the required packages

Other than things bundled in the OTP release Pleroma depends on:
* curl (to download the release build)
* unzip (needed to unpack release builds)
* ncurses (ERTS won't run without it)
* PostgreSQL (also utilizes extensions in postgresql-contrib)
* nginx (could be swapped with another reverse proxy but this guide covers only it)
* certbot (for Let's Encrypt certificates, could be swapped with another ACME client, but this guide covers only it)

Debian/Ubuntu:
```sh
apt install curl unzip libncurses5 postgresql postgresql-contrib nginx certbot
```
Alpine:

**Warning:** There has been some changes to musl on Alpine 3.10 which need an Elixir rebuild. Since the build machines are running Alpine 3.9 running the builds on 3.10 will likely fail with "dlsym: Resource temporarily unavailable". If you have not updated yet, replace `latest-stable` with `v3.9` in `/etc/apk/repositories`. If you have, try downgrading `musl` to `1.1.20-r3`
```sh
echo "http://nl.alpinelinux.org/alpine/v3.9/community" >> /etc/apk/repositories
apk update
apk add curl unzip ncurses postgresql postgresql-contrib nginx certbot
```

## Setup
### Configuring PostgreSQL
#### (Optional) Installing RUM indexes
RUM indexes are an alternative indexing scheme that is not included in PostgreSQL by default. You can read more about them on the [Configuration page](config.html#rum-indexing-for-full-text-search). They are completely optional and most of the time are not worth it, especially if you are running a single user instance (unless you absolutely need ordered search results).

Debian/Ubuntu (available only on Buster/19.04):
```sh
apt install postgresql-11-rum
```
Alpine:
```sh
apk add gcc make git postgresql-dev musl-dev
git clone https://github.com/postgrespro/rum /tmp/rum
cd /tmp/rum
make USE_PGXS=1
make USE_PGXS=1 install
cd
rm -r /tmp/rum
```
#### (Optional) Performance configuration
For optimal performance, you may use [PGTune](https://pgtune.leopard.in.ua), don't forget to restart postgresql after editing the configuration

Debian/Ubuntu:
```sh
systemctl restart postgresql
```
Alpine:
```sh
rc-service postgresql restart
```
### Installing Pleroma
```sh
# Create the Pleroma user
adduser --system --shell  /bin/false --home /opt/pleroma pleroma

# Set the flavour environment variable to the string you got in Detecting flavour section. 
# For example if the flavour is `arm64-musl` the command will be
export FLAVOUR="arm64-musl"

# Clone the release build into a temporary directory and unpack it
su pleroma -s $SHELL -lc "
curl 'https://git.pleroma.social/api/v4/projects/2/jobs/artifacts/master/download?job=$FLAVOUR' -o /tmp/pleroma.zip
unzip /tmp/pleroma.zip -d /tmp/
"

# Move the release to the home directory and delete temporary files
su pleroma -s $SHELL -lc "
mv /tmp/release/* /opt/pleroma
rmdir /tmp/release
rm /tmp/pleroma.zip
"
# Create uploads directory and set proper permissions (skip if planning to use a remote uploader)
# Note: It does not have to be `/var/lib/pleroma/uploads`, the config generator will ask about the upload directory later

mkdir -p /var/lib/pleroma/uploads
chown -R pleroma /var/lib/pleroma

# Create custom public files directory (custom emojis, frontend bundle overrides, robots.txt, etc.)
# Note: It does not have to be `/var/lib/pleroma/static`, the config generator will ask about the custom public files directory later
mkdir -p /var/lib/pleroma/static
chown -R pleroma /var/lib/pleroma

# Create a config directory
mkdir -p /etc/pleroma
chown -R pleroma /etc/pleroma

# Run the config generator
su pleroma -s $SHELL -lc "./bin/pleroma_ctl instance gen --output /etc/pleroma/config.exs --output-psql /tmp/setup_db.psql"

# Create the postgres database
su postgres -s $SHELL -lc "psql -f /tmp/setup_db.psql"

# If you have installed RUM indexes add
# `config :pleroma, :database, rum_enabled: true`
# to the end of /etc/pleroma/config.exs before proceeding

# Create the database schema
su pleroma -s $SHELL -lc "./bin/pleroma_ctl migrate"

# If you have installed RUM indexes uncommend and run
# su pleroma -s $SHELL -lc "./bin/pleroma_ctl migrate --migrations-path priv/repo/optional_migrations/rum_indexing/"

# Start the instance to verify that everything is working as expected
su pleroma -s $SHELL -lc "./bin/pleroma daemon"

# Wait for about 20 seconds and query the instance endpoint, if it shows your uri, name and email correctly, you are configured correctly
sleep 20 && curl http://localhost:4000/api/v1/instance

# Stop the instance
su pleroma -s $SHELL -lc "./bin/pleroma stop"
```

### Setting up nginx and getting Let's Encrypt SSL certificaties

```sh
# Get a Let's Encrypt certificate
certbot certonly --standalone --preferred-challenges http -d yourinstance.tld

# Copy the Pleroma nginx configuration to the nginx folder
# The location of nginx configs is dependent on the distro

# For Debian/Ubuntu:
cp /opt/pleroma/installation/pleroma.nginx /etc/nginx/sites-available/pleroma.nginx
ln -s /etc/nginx/sites-available/pleroma.nginx /etc/nginx/sites-enabled/pleroma.nginx
# For Alpine
cp /opt/pleroma/installation/pleroma.nginx /etc/nginx/conf.d/pleroma.conf
# If your distro does not have either of those you can append
# `include /etc/nginx/pleroma.conf` to the end of the http section in /etc/nginx/nginx.conf and
cp /opt/pleroma/installation/pleroma.nginx /etc/nginx/pleroma.conf

# Edit the nginx config replacing example.tld with your (sub)domain
$EDITOR path-to-nginx-config

# Verify that the config is valid
nginx -t

# Start nginx
# For Debian/Ubuntu:
systemctl start nginx
# For Alpine
rc-service nginx start
```

At this point if you open your (sub)domain in a browser you should see a 502 error, that's because pleroma is not started yet.

### Setting up a system service
Debian/Ubuntu:
```sh
# Copy the service into a proper directory
cp /opt/pleroma/installation/pleroma.service /etc/systemd/system/pleroma.service

# Start pleroma and enable it on boot
systemctl start pleroma
systemctl enable pleroma
```
Alpine:
```sh
# Copy the service into a proper directory
cp /opt/pleroma/installation/init.d/pleroma /etc/init.d/pleroma

# Start pleroma and enable it on boot
rc-service pleroma start
rc-update add pleroma
```

If everything worked, you should see Pleroma-FE when visiting your domain. If that didn't happen, try reviewing the installation steps, starting Pleroma in the foreground and seeing if there are any errrors. 

Still doesn't work? Feel free to contact us on [#pleroma on freenode](https://webchat.freenode.net/?channels=%23pleroma) or via matrix at <https://matrix.heldscal.la/#/room/#freenode_#pleroma:matrix.org>, you can also [file an issue on our Gitlab](https://git.pleroma.social/pleroma/pleroma/issues/new)

## Post installation

### Setting up auto-renew Let's Encrypt certificate
### Running Mix tasks
### Updating
