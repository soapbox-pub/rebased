# Switching a from-source install to OTP releases

## What are OTP releases?
OTP releases are as close as you can get to binary releases with Erlang/Elixir. The release is self-contained, and provides everything needed to boot it, it is easily administered via the provided shell script to open up a remote console, start/stop/restart the release, start in the background, send remote commands, and more.

## Pre-requisites
You will be running commands as root. If you aren't root already, please elevate your priviledges by executing `sudo su`/`su`.

The system needs to have `curl` and `unzip` installed for downloading and unpacking release builds.

```sh tab="Alpine"
apk add curl unzip
```

```sh tab="Debian/Ubuntu"
apt install curl unzip
```

## Moving content out of the application directory
When using OTP releases the application directory changes with every version so it would be a bother to keep content there (and also dangerous unless `--no-rm` option is used when updating). Fortunately almost all paths in Pleroma are configurable, so it is possible to move them out of there.

Pleroma should be stopped before proceeding.

### Moving uploads/custom public files directory

```sh
# Create uploads directory and set proper permissions (skip if using a remote uploader)
# Note: It does not have to be `/var/lib/pleroma/uploads`, you can configure it to be something else later
mkdir -p /var/lib/pleroma/uploads
chown -R pleroma /var/lib/pleroma

# Create custom public files directory
# Note: It does not have to be `/var/lib/pleroma/static`, you can configure it to be something else later
mkdir -p /var/lib/pleroma/static
chown -R pleroma /var/lib/pleroma

# If you use the local uploader with default settings your uploads should be located in `~pleroma/uploads`
mv ~pleroma/uploads/* /var/lib/pleroma/uploads

# If you have created the custom public files directory with default settings it should be located in `~pleroma/instance/static`
mv ~pleroma/instance/static /var/lib/pleroma/static
```

### Moving emoji
Assuming you have all emojis in subdirectories of `priv/static/emoji` moving them can be done with
```sh
mkdir /var/lib/pleroma/static/emoji
ls -d ~pleroma/priv/static/emoji/*/ | xargs -i sh -c 'mv "{}" "/var/lib/pleroma/static/emoji/$(basename {})"'
```

But, if for some reason you have custom emojis in the root directory you should copy the whole directory instead.
```sh
mv ~pleroma/priv/static/emoji /var/lib/pleroma/static/emoji
```
and then copy custom emojis to `/var/lib/pleroma/static/emoji/custom`. 

This is needed because storing custom emojis in the root directory is deprecated, but if you just move them to `/var/lib/pleroma/static/emoji/custom` it will break emoji urls on old posts.

Note that globs have been replaced with `pack_extensions`, so if your emojis are not in png/gif you should [modify the default value](../configuration/cheatsheet.md#emoji).

### Moving the config
```sh
# Create the config directory
# The default path for Pleroma config is /etc/pleroma/config.exs
# but it can be set via PLEROMA_CONFIG_PATH environment variable
mkdir -p /etc/pleroma

# Move the config file
mv ~pleroma/config/prod.secret.exs /etc/pleroma/config.exs

# Change `use Mix.Config` at the top to `import Config`
$EDITOR /etc/pleroma/config.exs
```
## Installing the release
Before proceeding, get the flavour from [Detecting flavour](otp_en.md#detecting-flavour) section in OTP installation guide.
```sh
# Delete all files in pleroma user's directory
rm -r ~pleroma/*

# Set the flavour environment variable to the string you got in Detecting flavour section.
# For example if the flavour is `amd64-musl` the command will be
export FLAVOUR="amd64-musl"

# Clone the release build into a temporary directory and unpack it
# Replace `stable` with `unstable` if you want to run the unstable branch
su pleroma -s $SHELL -lc "
curl 'https://git.pleroma.social/api/v4/projects/2/jobs/artifacts/stable/download?job=$FLAVOUR' -o /tmp/pleroma.zip
unzip /tmp/pleroma.zip -d /tmp/
"

# Move the release to the home directory and delete temporary files
su pleroma -s $SHELL -lc "
mv /tmp/release/* ~pleroma/
rmdir /tmp/release
rm /tmp/pleroma.zip
"

# Start the instance to verify that everything is working as expected
su pleroma -s $SHELL -lc "./bin/pleroma daemon"

# Wait for about 20 seconds and query the instance endpoint, if it shows your uri, name and email correctly, you are configured correctly
sleep 20 && curl http://localhost:4000/api/v1/instance

# Stop the instance
su pleroma -s $SHELL -lc "./bin/pleroma stop"
```

## Setting up a system service
OTP releases have different service files than from-source installs so they need to be copied over again.

**Warning:** The service files assume pleroma user's home directory is `/opt/pleroma`, please make sure all paths fit your installation.

```sh tab="Alpine"
# Copy the service into a proper directory
cp -f ~pleroma/installation/init.d/pleroma /etc/init.d/pleroma

# Start pleroma
rc-service pleroma start
```

```sh tab="Debian/Ubuntu"
# Copy the service into a proper directory
cp ~pleroma/installation/pleroma.service /etc/systemd/system/pleroma.service

# Reload service files
systemctl daemon-reload

# Reenable pleroma to start on boot
systemctl reenable pleroma

# Start pleroma
systemctl start pleroma
```

## Running mix tasks
Refer to [Running mix tasks](otp_en.md#running-mix-tasks) section from OTP release installation guide.
## Updating
Refer to [Updating](otp_en.md#updating) section from OTP release installation guide.
