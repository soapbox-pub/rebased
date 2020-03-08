# I2P Federation and Accessability

This guide is going to focus on the Pleroma federation aspect. The actual installation is neatly explained in the official documentation, and more likely to remain up-to-date.
It might be added to this guide if there will be a need for that.

We're going to use I2PD for its lightweightness over the official client.
Follow the documentation according to your distro: https://i2pd.readthedocs.io/en/latest/user-guide/install/#installing

How to run it: https://i2pd.readthedocs.io/en/latest/user-guide/run/

## I2P Federation

There are 2 ways to go about this.
One using the config, and one using external software (fedproxy). The external software works better so far.

### Using the Config

**Warning:** So far, everytime I followed this way of federating using I2P, the rest of my federation stopped working. I'm leaving this here in case it will help with making it work.

Assuming you're running in prod, cd to your Pleroma folder and append the following to `config/prod.secret.exs`:
```
config :pleroma, :http, proxy_url: {:socks5, :localhost, 4447}
```
And then run the following:
```
su pleroma
MIX_ENV=prod mix deps.get
MIX_ENV=prod mix ecto.migrate
exit
```
You can restart I2PD here and finish if you don't wish to make your instance viewable or accessible over I2P.
```
systemctl stop i2pd.service --no-block
systemctl start i2pd.service
```
*Notice:* The stop command initiates a graceful shutdown process, i2pd stops after finishing to route transit tunnels (maximum 10 minutes).

You can change the socks proxy port in `/etc/i2pd/i2pd.conf`.

### Using Fedproxy

Fedproxy passes through clearnet requests direct to where they are going. It doesn't force anything over Tor.

To use [fedproxy](https://github.com/majestrate/fedproxy) you'll need to install Golang.
```
apt install golang
```
Use a different user than pleroma or root. Run the following to add the Gopath to your ~/.bashrc.
```
echo "export GOPATH=/home/ren/.go" >> ~/.bashrc
```
Restart that bash session (you can exit and log back in).
Run the following to get fedproxy.
```
go get -u github.com/majestrate/fedproxy$
cp $(GOPATH)/bin/fedproxy /usr/local/bin/fedproxy
```
And then the following to start it for I2P only.
```
fedproxy 127.0.0.1:2000 127.0.0.1:4447
```
If you want to also use it for Tor, add `127.0.0.1:9050` to that command.
You'll also need to modify your Pleroma config.

Assuming you're running in prod, cd to your Pleroma folder and append the following to `config/prod.secret.exs`:
```
config :pleroma, :http, proxy_url: {:socks5, :localhost, 2000}
```
And then run the following:
```
su pleroma
MIX_ENV=prod mix deps.get
MIX_ENV=prod mix ecto.migrate
exit
```
You can restart I2PD here and finish if you don't wish to make your instance viewable or accessible over I2P.

```
systemctl stop i2pd.service --no-block
systemctl start i2pd.service
```
*Notice:* The stop command initiates a graceful shutdown process, i2pd stops after finishing to route transit tunnels (maximum 10 minutes).

You can change the socks proxy port in `/etc/i2pd/i2pd.conf`.

## I2P Instance Access

Make your instance accessible using I2P.

Add the following to your I2PD config `/etc/i2pd/tunnels.conf`:
```
[pleroma]
type = http
host = 127.0.0.1
port = 14447
keys = pleroma.dat
```
Restart I2PD:
```
systemctl stop i2pd.service --no-block
systemctl start i2pd.service
```
*Notice:* The stop command initiates a graceful shutdown process, i2pd stops after finishing to route transit tunnels (maximum 10 minutes).

Now you'll have to find your address.
To do that you can download and use I2PD tools.[^1]  
Or you'll need to access your web-console on localhost:7070.
If you don't have a GUI, you'll have to SSH tunnel into it like this:
`ssh -L 7070:127.0.0.1:7070 user@ip -p port`.
Now you can access it at localhost:7070.
Go to I2P tunnels page. Look for Server tunnels and you will see an address that ends with `.b32.i2p` next to "pleroma".
This is your site's address.

### I2P-only Instance

If creating an I2P-only instance, open `config/prod.secret.exs` and under "config :pleroma, Pleroma.Web.Endpoint," edit "https" and "port: 443" to the following:
```
   url: [host: "i2paddress", scheme: "http", port: 80],
```
In addition to that, replace the existing nginx config's contents with the example below.

### Existing Instance (Clearnet Instance)

If not an I2P-only instance, add the nginx config below to your existing config at `/etc/nginx/sites-enabled/pleroma.nginx`.

And for both cases, disable CSP in Pleroma's config (STS is disabled by default) so you can define those yourself separately from the clearnet (if your instance is also on the clearnet).
Copy the following into the `config/prod.secret.exs` in your Pleroma folder (/home/pleroma/pleroma/):
```
config :pleroma, :http_security,
  enabled: false
```

Use this as the Nginx config:
```
proxy_cache_path /tmp/pleroma-media-cache levels=1:2 keys_zone=pleroma_media_cache:10m max_size=10g inactive=720m use_temp_path=off;
# The above already exists in a clearnet instance's config.
# If not, add it.

server {
    listen 127.0.0.1:14447;
    server_name youri2paddress;

    # Comment to enable logs
    access_log /dev/null;
    error_log /dev/null;

    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript application/activity+json application/atom+xml;

    client_max_body_size 16m;

    location / {

        add_header X-XSS-Protection "1; mode=block";
        add_header X-Permitted-Cross-Domain-Policies none;
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header Referrer-Policy same-origin;
        add_header X-Download-Options noopen;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $http_host;

        proxy_pass http://localhost:4000;

        client_max_body_size 16m;
    }

    location /proxy {
        proxy_cache pleroma_media_cache;
        proxy_cache_lock on;
        proxy_ignore_client_abort on;
        proxy_pass http://localhost:4000;
    }
}
```
reload Nginx:
```
systemctl stop i2pd.service --no-block
systemctl start i2pd.service
```
*Notice:* The stop command initiates a graceful shutdown process, i2pd stops after finishing to route transit tunnels (maximum 10 minutes).

You should now be able to both access your instance using I2P and federate with other I2P instances!

[^1]: [I2PD tools](https://github.com/purplei2p/i2pd-tools) to print information about a router info file or an I2P private key, generate an I2P private key, and generate vanity addresses.

### Possible Issues

Will be added when encountered.
