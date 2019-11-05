import Config

config :pleroma, :instance, static: "/var/lib/pleroma/static"
config :pleroma, Pleroma.Uploaders.Local, uploads: "/var/lib/pleroma/uploads"

config_path = System.get_env("PLEROMA_CONFIG_PATH") || "/etc/pleroma/config.exs"

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
