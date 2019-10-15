# Installing on OpenBSD
This guide describes the installation and configuration of pleroma (and the required software to run it) on a single OpenBSD 6.4 server.
For any additional information regarding commands and configuration files mentioned here, check the man pages [online](https://man.openbsd.org/) or directly on your server with the man command.

#### Required software
The following packages need to be installed:
  * elixir
  * gmake
  * ImageMagick
  * git
  * postgresql-server
  * postgresql-contrib

To install them, run the following command (with doas or as root):  
`pkg_add elixir gmake ImageMagick git postgresql-server postgresql-contrib`

Pleroma requires a reverse proxy, OpenBSD has relayd in base (and is used in this guide) and packages/ports are available for nginx (www/nginx) and apache (www/apache-httpd). Independently of the reverse proxy, [acme-client(1)](https://man.openbsd.org/acme-client) can be used to get a certificate from Let's Encrypt.

#### Creating the pleroma user
Pleroma will be run by a dedicated user, \_pleroma. Before creating it, insert the following lines in login.conf:
```
pleroma:\
	:datasize-max=1536M:\
	:datasize-cur=1536M:\
	:openfiles-max=4096
```
This creates a "pleroma" login class and sets higher values than default for datasize and openfiles (see [login.conf(5)](https://man.openbsd.org/login.conf)), this is required to avoid having pleroma crash some time after starting.

Create the \_pleroma user, assign it the pleroma login class and create its home directory (/home/\_pleroma/): `useradd -m -L pleroma _pleroma`

#### Clone pleroma's directory
Enter a shell as the \_pleroma user. As root, run `su _pleroma -;cd`. Then clone the repository with `git clone -b stable https://git.pleroma.social/pleroma/pleroma.git`. Pleroma is now installed in /home/\_pleroma/pleroma/, it will be configured and started at the end of this guide.

#### Postgresql
Start a shell as the \_postgresql user (as root run `su _postgresql -` then run the `initdb` command to initialize postgresql:  
If you wish to not use the default location for postgresql's data (/var/postgresql/data), add the following switch at the end of the command: `-D <path>` and modify the `datadir` variable in the /etc/rc.d/postgresql script.

When this is done, enable postgresql so that it starts on boot and start it. As root, run:
```
rcctl enable postgresql
rcctl start postgresql
```
To check that it started properly and didn't fail right after starting, you can run `ps aux | grep postgres`, there should be multiple lines of output.

#### httpd
httpd will have three fuctions:
  * redirect requests trying to reach the instance over http to the https URL
  * serve a robots.txt file
  * get Let's Encrypt certificates, with acme-client

Insert the following config in httpd.conf:
```
# $OpenBSD: httpd.conf,v 1.17 2017/04/16 08:50:49 ajacoutot Exp $

ext_inet="<IPv4 address>"
ext_inet6="<IPv6 address>"

server "default" {
	listen on $ext_inet port 80 # Comment to disable listening on IPv4
	listen on $ext_inet6 port 80 # Comment to disable listening on IPv6
	listen on 127.0.0.1 port 80 # Do NOT comment this line

	log syslog
	directory no index

	location "/.well-known/acme-challenge/*" {
		root "/acme"
		request strip 2
	}

	location "/robots.txt" { root "/htdocs/local/" }
	location "/*" { block return 302 "https://$HTTP_HOST$REQUEST_URI" }
}

types {
	include "/usr/share/misc/mime.types"
}
```
Do not forget to change *\<IPv4/6 address\>* to your server's address(es). If httpd should only listen on one protocol family, comment one of the two first *listen* options.

Create the /var/www/htdocs/local/ folder and write the content of your robots.txt in /var/www/htdocs/local/robots.txt.  
Check the configuration with `httpd -n`, if it is OK enable and start httpd (as root):
```
rcctl enable httpd
rcctl start httpd
```

#### acme-client
acme-client is used to get SSL/TLS certificates from Let's Encrypt. 
Insert the following configuration in /etc/acme-client.conf:
```
#
# $OpenBSD: acme-client.conf,v 1.4 2017/03/22 11:14:14 benno Exp $
#

authority letsencrypt-<domain name> {
	#agreement url "https://letsencrypt.org/documents/LE-SA-v1.2-November-15-2017.pdf"
	api url "https://acme-v01.api.letsencrypt.org/directory"
	account key "/etc/acme/letsencrypt-privkey-<domain name>.pem"
}

domain <domain name> {
	domain key "/etc/ssl/private/<domain name>.key"
	domain certificate "/etc/ssl/<domain name>.crt"
	domain full chain certificate "/etc/ssl/<domain name>.fullchain.pem"
	sign with letsencrypt-<domain name>
	challengedir "/var/www/acme/"
}
```
Replace *\<domain name\>* by the domain name you'll use for your instance. As root, run `acme-client -n` to check the config, then `acme-client -ADv <domain name>` to create account and domain keys, and request a certificate for the first time.  
Make acme-client run everyday by adding it in /etc/daily.local. As root, run the following command: `echo "acme-client <domain name>" >> /etc/daily.local`.

Relayd will look for certificates and keys based on the address it listens on (see next part), the easiest way to make them available to relayd is to create a link, as root run:
```
ln -s /etc/ssl/<domain name>.fullchain.pem /etc/ssl/<IP address>.crt
ln -s /etc/ssl/private/<domain name>.key /etc/ssl/private/<IP address>.key
```
This will have to be done for each IPv4 and IPv6 address relayd listens on.

#### relayd
relayd will be used as the reverse proxy sitting in front of pleroma. 
Insert the following configuration in /etc/relayd.conf:
```
# $OpenBSD: relayd.conf,v 1.4 2018/03/23 09:55:06 claudio Exp $

ext_inet="<IPv4 address>"
ext_inet6="<IPv6 address>"

table <pleroma_server> { 127.0.0.1 }
table <httpd_server> { 127.0.0.1 }

http protocol plerup { # Protocol for upstream pleroma server
	#tcp { nodelay, sack, socket buffer 65536, backlog 128 } # Uncomment and adjust as you see fit
	tls ciphers "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305"
	tls ecdhe secp384r1

	# Forward some paths to the local server (as pleroma won't respond to them as you might want)
	pass request quick path "/robots.txt" forward to <httpd_server>

	# Append a bunch of headers
	match request header append "X-Forwarded-For" value "$REMOTE_ADDR" # This two header and the next one are not strictly required by pleroma but adding them won't hurt
	match request header append "X-Forwarded-By" value "$SERVER_ADDR:$SERVER_PORT"

	match response header append "X-XSS-Protection" value "1; mode=block"
	match response header append "X-Permitted-Cross-Domain-Policies" value "none"
	match response header append "X-Frame-Options" value "DENY"
	match response header append "X-Content-Type-Options" value "nosniff"
	match response header append "Referrer-Policy" value "same-origin"
	match response header append "X-Download-Options" value "noopen"
	match response header append "Content-Security-Policy" value "default-src 'none'; base-uri 'self'; form-action 'self'; img-src 'self' data: https:; media-src 'self' https:; style-src 'self' 'unsafe-inline'; font-src 'self'; script-src 'self'; connect-src 'self' wss://CHANGEME.tld; upgrade-insecure-requests;" # Modify "CHANGEME.tld" and set your instance's domain here
	match request header append "Connection" value "upgrade"
	#match response header append "Strict-Transport-Security" value "max-age=31536000; includeSubDomains" # Uncomment this only after you get HTTPS working.

	# If you do not want remote frontends to be able to access your Pleroma backend server, comment these lines
	match response header append "Access-Control-Allow-Origin" value "*"
	match response header append "Access-Control-Allow-Methods" value "POST, PUT, DELETE, GET, PATCH, OPTIONS"
	match response header append "Access-Control-Allow-Headers" value "Authorization, Content-Type, Idempotency-Key"
	match response header append "Access-Control-Expose-Headers" value "Link, X-RateLimit-Reset, X-RateLimit-Limit, X-RateLimit-Remaining, X-Request-Id"
	# Stop commenting lines here
}

relay wwwtls {
	listen on $ext_inet port https tls # Comment to disable listening on IPv4
	listen on $ext_inet6 port https tls # Comment to disable listening on IPv6

	protocol plerup

	forward to <pleroma_server> port 4000 check http "/" code 200
	forward to <httpd_server> port 80 check http "/robots.txt" code 200
}
```
Again, change *\<IPv4/6 address\>* to your server's address(es) and comment one of the two *listen* options if needed. Also change *wss://CHANGEME.tld* to *wss://\<your instance's domain name\>*.  
Check the configuration with `relayd -n`, if it is OK enable and start relayd (as root):
```
rcctl enable relayd
rcctl start relayd
```

#### pf
Enabling and configuring pf is highly recommended.  
In /etc/pf.conf, insert the following configuration:
```
# Macros
if="<network interface>"
authorized_ssh_clients="any"

# Skip traffic on loopback interface
set skip on lo

# Default behavior
set block-policy drop
block in log all
pass out quick

# Security features
match in all scrub (no-df random-id)
block in log from urpf-failed

# Rules
pass in quick on $if inet proto icmp to ($if) icmp-type { echoreq unreach paramprob trace } # ICMP
pass in quick on $if inet6 proto icmp6 to ($if) icmp6-type { echoreq unreach paramprob timex toobig } # ICMPv6
pass in quick on $if proto tcp to ($if) port { http https } # relayd/httpd
pass in quick on $if proto tcp from $authorized_ssh_clients to ($if) port ssh
```
Replace *\<network interface\>* by your server's network interface name (which you can get with ifconfig). Consider replacing the content of the authorized\_ssh\_clients macro by, for exemple, your home IP address, to avoid SSH connection attempts from bots.

Check pf's configuration by running `pfctl -nf /etc/pf.conf`, load it with `pfctl -f /etc/pf.conf` and enable pf at boot with `rcctl enable pf`.

#### Configure and start pleroma
Enter a shell as \_pleroma (as root `su _pleroma -`) and enter pleroma's installation directory (`cd ~/pleroma/`).  
Then follow the main installation guide:
  * run `mix deps.get`
  * run `mix pleroma.instance gen` and enter your instance's information when asked
  * copy config/generated\_config.exs to config/prod.secret.exs. The default values should be sufficient but you should edit it and check that everything seems OK.
  * exit your current shell back to a root one and run `psql -U postgres -f /home/_pleroma/config/setup_db.psql` to setup the database.
  * return to a \_pleroma shell into pleroma's installation directory (`su _pleroma -;cd ~/pleroma`) and run `MIX_ENV=prod mix ecto.migrate`

As \_pleroma in /home/\_pleroma/pleroma, you can now run `LC_ALL=en_US.UTF-8 MIX_ENV=prod mix phx.server` to start your instance.  
In another SSH session/tmux window, check that it is working properly by running `ftp -MVo - http://127.0.0.1:4000/api/v1/instance`, you should get json output. Double-check that *uri*'s value is your instance's domain name.

##### Starting pleroma at boot
An rc script to automatically start pleroma at boot hasn't been written yet, it can be run in a tmux session (tmux is in base).
