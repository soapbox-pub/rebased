# Installing Soapbox on Ubuntu

We recommend installing Soapbox on a **dedicated VPS (virtual private server) running Ubuntu 20.04 LTS**.
You should get your VPS up and running before starting this guide.

Some popular VPS hosting providers include:

- [DigitalOcean](https://m.do.co/c/84e2ff1e790f) <sup>[referral link]</sup> &mdash; easy to use
- [Hetzner Cloud](https://www.hetzner.com/cloud) &mdash; cheap
- [BuyVM](https://buyvm.net/) &mdash; supports free speech

Expect to spend between **$10&ndash;15 USD/mo**, depending on the size of your community and how you choose to configure it.

You should already have a **domain name** from a registrar like [Namecheap](https://www.namecheap.com/) or [Epik](https://www.epik.com/).
Create an `A` record with your registrar pointing to the IP address of your VPS.

## 1. Shelling in

Once your VPS is running, you'll need to open a **terminal program** on your computer.
This will allow you to remotely connect to the server so you can run commands and install Soapbox.

![Screenshot_from_2021-04-28_14.06.37](https://gitlab.com/soapbox-pub/soapbox/uploads/1b4f956398736e2016d6d30b3d9567c6/Screenshot_from_2021-04-28_14.06.37.png)

Linux and Mac users should have a terminal program pre-installed (it's just called **"Terminal"**), but Windows users may need to install [Cygwin](https://www.cygwin.com/) first.

Once the terminal is open, connect to your server with the username and IP address provided by your VPS host.
It will likely prompt for a password.

```sh
ssh root@123.456.789
```

If you see a screen that looks like this, you've succeeded:

```
Welcome to Ubuntu 20.04.2 LTS (GNU/Linux 5.4.0-65-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Wed Apr 28 18:59:27 UTC 2021

  System load:  1.86                Processes:              201
  Usage of /:   66.1% of 146.15GB   Users logged in:        0
  Memory usage: 29%                 IPv4 address for ens18: 10.0.0.100
  Swap usage:   4%                  IPv4 address for ens19: 192.168.1.100

 * Pure upstream Kubernetes 1.21, smallest, simplest cluster ops!

     https://microk8s.io/

79 updates can be installed immediately.
0 of these updates are security updates.
To see these additional updates run: apt list --upgradable


Last login: Tue Apr 27 17:28:56 2021 from 98.198.61.119
root@gleasonator:~#
```

## 2. System setup

Before installing Soapbox, we have to prepare the system.

### 2.a. Install updates

Usually a fresh VPS already has outdated software, so run the following commands to update it:

```shell
sudo apt update
sudo apt upgrade
```

When prompted (`[Y/n]`) type `Y` and hit Enter.

### 2.b. Install system dependencies

Soapbox relies on some additional system software in order to function.
Install them with the following command:

```shell
sudo apt install git build-essential postgresql postgresql-contrib cmake libmagic-dev imagemagick ffmpeg libimage-exiftool-perl nginx certbot
```

### 2.c. Install Elixir

Soapbox uses the Elixir programming language (based on Erlang).
Unfortunately the latest version is not included in Ubuntu by default, so we have to add a third-party repository before we can install it.

To install the Elixir repository, use these commands:

```shell
wget -P /tmp/ https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
sudo dpkg -i /tmp/erlang-solutions_2.0_all.deb
```

Now we can install Elixir (and Erlang):

```shell
sudo apt update
sudo apt install elixir erlang-dev erlang-nox
```

### 2.d. Create the Pleroma user

For security reasons, it's best to run Soapbox as a separate user with limited access.

We'll create this user and call it `pleroma`:

```shell
sudo useradd -r -s /bin/false -m -d /var/lib/pleroma -U pleroma
```

## 3. Install Soapbox

Finally! It's time to install Soapbox itself.
Let's get things up and running.

### 3.a. Downloading the source code

We'll need to create a folder to hold the Soapbox source code, then download it with git:

```shell
sudo mkdir -p /opt/pleroma
sudo chown -R pleroma:pleroma /opt/pleroma
sudo -Hu pleroma git clone -b stable https://gitlab.com/soapbox-pub/soapbox /opt/pleroma
```

### 3.b. Install Elixir dependencies

First let's enter the Soapbox source code directory:

```shell
cd /opt/pleroma
```

Soapbox depends on third-party Elixir modules which need to be downloaded:

```shell
sudo -Hu pleroma mix deps.get
```

If it asks you to install `Hex`, answer `yes`:

### 3.c. Generate the configuration

It's time to preconfigure our instance.
The following command will set up some basics such as your domain name.

```sh
sudo -Hu pleroma mix pleroma.instance gen
```

* Answer with `yes` if it asks you to install `rebar3`.

* This may take some time, because parts of pleroma get compiled first.

* After that it will ask you a few questions about your instance and generates a configuration file in `config/generated_config.exs`.

Check if the configuration looks right.
If so, rename it to `prod.secret.exs`:

```shell
sudo -Hu pleroma mv config/{generated_config.exs,prod.secret.exs}
```

### 3.d. Provision the database

The previous section also created a file called `config/setup_db.psql`, which you can use to create the database:

```shell
sudo -Hu postgres psql -f config/setup_db.psql
```

Now run the database migration:

```shell
sudo -Hu pleroma MIX_ENV=prod mix ecto.migrate
```

### 3.e. Start Soapbox

Copy the systemd service and enable it to start Soapbox:

```shell
sudo cp /opt/pleroma/installation/pleroma.service /etc/systemd/system/pleroma.service
sudo systemctl enable --now pleroma.service
```

If you've made it this far, congrats!
You're very close to being done.
Your Soapbox server is running, and you just need to make it accessible to the outside world.

## 4. Getting online

The last step is to make your server accessible to the outside world.
We'll achieve that by installing Nginx and enabling HTTPS support.

### 4.a. HTTPS

We'll use certbot to get an SSL certificate.

First, shut off Nginx:

```sh
systemctl stop nginx
```

Now you can get the certificate:

```shell
sudo mkdir -p /var/lib/letsencrypt/
sudo certbot certonly --email <your@emailaddress> -d <yourdomain> --standalone
```

Replace `<your@emailaddress>` and `<yourdomain>` with real values.

### 4.b. Nginx

Copy the example nginx configuration and activate it:

```shell
sudo cp /opt/pleroma/installation/pleroma.nginx /etc/nginx/sites-available/pleroma.nginx
sudo ln -s /etc/nginx/sites-available/pleroma.nginx /etc/nginx/sites-enabled/pleroma.nginx
```

Before starting Nginx again, edit the configuration and change it to your needs (e.g. change servername, change cert paths)

Enable and start nginx:

```shell
sudo systemctl enable --now nginx.service
```

🎉 Congrats, you're done!
Check your site in a browser and it should be online.

## 5. Post-installation

Below are some additional steps you can take after you've finished installation.

### Create your first user

If your instance is up and running, you can create your first user with administrative rights with the following task:

```shell
sudo -Hu pleroma MIX_ENV=prod mix pleroma.user new <username> <your@emailaddress> --admin
```

### Renewing SSL

If you need to renew the certificate in the future, uncomment the relevant location block in the nginx config and run:

```shell
sudo certbot certonly --email <your@emailaddress> -d <yourdomain> --webroot -w /var/lib/letsencrypt/
```

## Questions

If you have questions or run into trouble, please [create an issue](https://gitlab.com/soapbox-pub/soapbox/-/issues) on the Soapbox GitLab.
