# Creating trusted OAuth App

{! backend/administration/CLI_tasks/general_cli_task_info.include !}

## Create trusted OAuth App.

Optional params:
  * `-s SCOPES` - scopes for app, e.g. `read,write,follow,push`.

=== "OTP"

    ```sh
     ./bin/pleroma_ctl app create -n APP_NAME -r REDIRECT_URI
    ```

=== "From Source"

    ```sh
    mix pleroma.app create -n APP_NAME -r REDIRECT_URI
    ```