# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.ReleaseRuntimeProviderTest do
  use ExUnit.Case, async: true

  alias Pleroma.Config.ReleaseRuntimeProvider

  describe "load/2" do
    test "loads release defaults config and warns about non-existent runtime config" do
      ExUnit.CaptureIO.capture_io(fn ->
        merged = ReleaseRuntimeProvider.load([], [])
        assert merged == Pleroma.Config.Holder.release_defaults()
      end) =~
        "!!! Config path is not declared! Please ensure it exists and that PLEROMA_CONFIG_PATH is unset or points to an existing file"
    end

    test "merged runtime config" do
      merged =
        ReleaseRuntimeProvider.load([], config_path: "test/fixtures/config/temp.secret.exs")

      assert merged[:pleroma][:first_setting] == [key: "value", key2: [Pleroma.Repo]]
      assert merged[:pleroma][:second_setting] == [key: "value2", key2: ["Activity"]]
    end

    test "merged exported config" do
      ExUnit.CaptureIO.capture_io(fn ->
        merged =
          ReleaseRuntimeProvider.load([],
            exported_config_path: "test/fixtures/config/temp.exported_from_db.secret.exs"
          )

        assert merged[:pleroma][:exported_config_merged]
      end) =~
        "!!! Config path is not declared! Please ensure it exists and that PLEROMA_CONFIG_PATH is unset or points to an existing file"
    end

    test "runtime config is merged with exported config" do
      merged =
        ReleaseRuntimeProvider.load([],
          config_path: "test/fixtures/config/temp.secret.exs",
          exported_config_path: "test/fixtures/config/temp.exported_from_db.secret.exs"
        )

      assert merged[:pleroma][:first_setting] == [key2: [Pleroma.Repo], key: "new value"]
    end
  end
end
