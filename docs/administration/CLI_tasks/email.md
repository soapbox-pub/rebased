# EMail administration tasks

{! backend/administration/CLI_tasks/general_cli_task_info.include !}

## Send test email (instance email by default)

=== "OTP"

    ```sh
     ./bin/pleroma_ctl email test [--to <destination email address>]
    ```

=== "From Source"

    ```sh
    mix pleroma.email test [--to <destination email address>]
    ```

Example:

=== "OTP"

    ```sh
    ./bin/pleroma_ctl email test --to root@example.org
    ```

=== "From Source"

    ```sh
    mix pleroma.email test --to root@example.org
    ```

## Send confirmation emails to all unconfirmed user accounts

=== "OTP"

    ```sh
     ./bin/pleroma_ctl email resend_confirmation_emails
    ```

=== "From Source"

    ```sh
    mix pleroma.email resend_confirmation_emails
    ```
