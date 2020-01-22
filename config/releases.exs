import Config

config :pleroma, :instance, static_dir: "/var/lib/pleroma/static"
config :pleroma, Pleroma.Uploaders.Local, uploads: "/var/lib/pleroma/uploads"
config :pleroma, :modules, runtime_dir: "/var/lib/pleroma/modules"

config_path = System.get_env("PLEROMA_CONFIG_PATH") || "/etc/pleroma/config.exs"

config :pleroma, release: true, config_path: config_path

if File.exists?(config_path) do
  import_config config_path
else
  warning = [
    IO.ANSI.red(),
    IO.ANSI.bright(),
    "!!! #{config_path} not found! Please ensure it exists and that PLEROMA_CONFIG_PATH is unset or points to an existing file",
    IO.ANSI.reset()
  ]

  IO.puts(warning)
end

exported_config =
  config_path
  |> Path.dirname()
  |> Path.join("prod.exported_from_db.secret.exs")

if File.exists?(exported_config) do
  import_config exported_config
end
