# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

import Config

config :pleroma, :first_setting, key: "value", key2: [Pleroma.Repo]

config :pleroma, :second_setting, key: "value2", key2: ["Activity"]

config :quack, level: :info

config :pleroma, Pleroma.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :postgrex, :json_library, Poison

config :pleroma, :database, rum_enabled: true
