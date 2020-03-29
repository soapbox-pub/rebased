# Managing instance configuration

{! backend/administration/CLI_tasks/general_cli_task_info.include !}

## Generate a new configuration file
```sh tab="OTP"
 ./bin/pleroma_ctl instance gen [option ...]
```

```sh tab="From Source"
mix pleroma.instance gen [option ...]
```


If any of the options are left unspecified, you will be prompted interactively.

### Options
- `-f`, `--force` - overwrite any output files
- `-o <path>`, `--output <path>` - the output file for the generated configuration
- `--output-psql <path>` - the output file for the generated PostgreSQL setup
- `--domain <domain>` - the domain of your instance
- `--instance-name <instance_name>` - the name of your instance
- `--admin-email <email>` - the email address of the instance admin
- `--notify-email <email>` - email address for notifications
- `--dbhost <hostname>` - the hostname of the PostgreSQL database to use
- `--dbname <database_name>` - the name of the database to use
- `--dbuser <username>` - the user (aka role) to use for the database connection
- `--dbpass <password>` - the password to use for the database connection
- `--rum <Y|N>` - Whether to enable RUM indexes
- `--indexable <Y|N>` - Allow/disallow indexing site by search engines
- `--db-configurable <Y|N>` - Allow/disallow configuring instance from admin part
- `--uploads-dir <path>` - the directory uploads go in when using a local uploader
- `--static-dir <path>` - the directory custom public files should be read from (custom emojis, frontend bundle overrides, robots.txt, etc.)
- `--listen-ip <ip>` - the ip the app should listen to, defaults to 127.0.0.1
- `--listen-port <port>` - the port the app should listen to, defaults to 4000
