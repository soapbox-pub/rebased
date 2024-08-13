# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.UploadsTest do
  alias Pleroma.Config
  alias Pleroma.Upload
  use Pleroma.DataCase, async: false

  import Mock

  setup_all do
    prep_uploads()
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
    end)

    :ok
  end

  setup do: clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.Local)

  describe "running migrate_local" do
    test "uploads migrated" do
      with_mock Upload,
        store: fn %Upload{name: _file, path: _path}, _opts -> {:ok, %{}} end do
        Mix.Tasks.Pleroma.Uploads.run(["migrate_local", "S3"])

        assert_received {:mix_shell, :info, [message]}
        assert message =~ "Migrating files from local"

        assert_received {:mix_shell, :info, [message]}

        assert %{"total_count" => total_count} =
                 Regex.named_captures(~r"^Found (?<total_count>\d+) uploads$", message)

        assert_received {:mix_shell, :info, [message]}

        # @logevery in Mix.Tasks.Pleroma.Uploads
        count =
          min(50, String.to_integer(total_count))
          |> to_string()

        assert %{"count" => ^count, "total_count" => ^total_count} =
                 Regex.named_captures(
                   ~r"^Uploaded (?<count>\d+)/(?<total_count>\d+) files$",
                   message
                 )
      end
    end

    test "nonexistent uploader" do
      assert_raise RuntimeError, ~r/The uploader .* is not an existing/, fn ->
        Mix.Tasks.Pleroma.Uploads.run(["migrate_local", "nonexistent"])
      end
    end
  end

  defp prep_uploads do
    upload_dir = Config.get([Pleroma.Uploaders.Local, :uploads])

    if not File.exists?(upload_dir) || File.ls!(upload_dir) == [] do
      File.mkdir_p(upload_dir)

      Path.join([upload_dir, "file.txt"])
      |> File.touch()
    end
  end
end
