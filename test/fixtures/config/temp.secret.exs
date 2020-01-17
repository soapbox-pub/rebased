use Mix.Config

config :pleroma, :first_setting, key: "value", key2: [Pleroma.Repo]

config :pleroma, :second_setting, key: "value2", key2: ["Activity"]

config :quack, level: :info

config :pleroma, Pleroma.Repo, pool: Ecto.Adapters.SQL.Sandbox
