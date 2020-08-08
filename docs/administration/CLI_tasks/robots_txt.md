# Managing robot.txt

{! backend/administration/CLI_tasks/general_cli_task_info.include !}

## Generate a new robot.txt file and add it to the static directory

The `robots.txt` that ships by default is permissive. It allows well-behaved search engines to index all of your instance's URIs.

If you want to generate a restrictive `robots.txt`, you can run the following mix task. The generated `robots.txt` will be written in your instance [static directory](../../../configuration/static_dir/).

```elixir tab="OTP"
./bin/pleroma_ctl robots_txt disallow_all
```

```elixir tab="From Source"
mix pleroma.robots_txt disallow_all
```
