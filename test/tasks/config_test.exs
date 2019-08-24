# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.ConfigTest do
  use Pleroma.DataCase
  alias Pleroma.Repo
  alias Pleroma.Web.AdminAPI.Config

  setup_all do
    Mix.shell(Mix.Shell.Process)
    temp_file = "config/temp.exported_from_db.secret.exs"

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
      Application.delete_env(:pleroma, :first_setting)
      Application.delete_env(:pleroma, :second_setting)
      :ok = File.rm(temp_file)
    end)

    {:ok, temp_file: temp_file}
  end

  clear_config_all([:instance, :dynamic_configuration]) do
    Pleroma.Config.put([:instance, :dynamic_configuration], true)
  end

  test "settings are migrated to db" do
    assert Repo.all(Config) == []

    Application.put_env(:pleroma, :first_setting, key: "value", key2: [Pleroma.Repo])
    Application.put_env(:pleroma, :second_setting, key: "value2", key2: [Pleroma.Activity])

    Mix.Tasks.Pleroma.Config.run(["migrate_to_db"])

    first_db = Config.get_by_params(%{group: "pleroma", key: ":first_setting"})
    second_db = Config.get_by_params(%{group: "pleroma", key: ":second_setting"})
    refute Config.get_by_params(%{group: "pleroma", key: "Pleroma.Repo"})

    assert Config.from_binary(first_db.value) == [key: "value", key2: [Pleroma.Repo]]
    assert Config.from_binary(second_db.value) == [key: "value2", key2: [Pleroma.Activity]]
  end

  test "settings are migrated to file and deleted from db", %{temp_file: temp_file} do
    Config.create(%{
      group: "pleroma",
      key: ":setting_first",
      value: [key: "value", key2: [Pleroma.Activity]]
    })

    Config.create(%{
      group: "pleroma",
      key: ":setting_second",
      value: [key: "valu2", key2: [Pleroma.Repo]]
    })

    Mix.Tasks.Pleroma.Config.run(["migrate_from_db", "temp", "true"])

    assert Repo.all(Config) == []
    assert File.exists?(temp_file)
    {:ok, file} = File.read(temp_file)

    assert file =~ "config :pleroma, :setting_first,"
    assert file =~ "config :pleroma, :setting_second,"
  end
end
