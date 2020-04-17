# Creating trusted OAuth App

{! backend/administration/CLI_tasks/general_cli_task_info.include !}

## Create trusted OAuth App.

Optional params:
  * `-s SCOPES` - scopes for app, e.g. `read,write,follow,push`.

```sh tab="OTP"
 ./bin/pleroma_ctl app create -n APP_NAME -r REDIRECT_URI
```

```sh tab="From Source"
mix pleroma.app create -n APP_NAME -r REDIRECT_URI
```