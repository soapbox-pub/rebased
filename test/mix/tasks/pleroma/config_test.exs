# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.ConfigTest do
  use Pleroma.DataCase

  import Pleroma.Factory

  alias Mix.Tasks.Pleroma.Config, as: MixTask
  alias Pleroma.ConfigDB
  alias Pleroma.Repo

  setup_all do
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
      Application.delete_env(:pleroma, :first_setting)
      Application.delete_env(:pleroma, :second_setting)
    end)

    :ok
  end

  defp config_records do
    ConfigDB
    |> Repo.all()
    |> Enum.sort()
  end

  defp insert_config_record(group, key, value) do
    insert(:config,
      group: group,
      key: key,
      value: value
    )
  end

  test "error if file with custom settings doesn't exist" do
    MixTask.migrate_to_db("config/non_existent_config_file.exs")

    msg =
      "To migrate settings, you must define custom settings in config/non_existent_config_file.exs."

    assert_receive {:mix_shell, :info, [^msg]}, 15
  end

  describe "migrate_to_db/1" do
    setup do
      clear_config(:configurable_from_database, true)
      clear_config([:quack, :level])
    end

    @tag capture_log: true
    test "config migration refused when deprecated settings are found" do
      clear_config([:media_proxy, :whitelist], ["domain_without_scheme.com"])
      assert config_records() == []

      MixTask.migrate_to_db("test/fixtures/config/temp.secret.exs")

      assert_received {:mix_shell, :error, [message]}

      assert message =~
               "Migration is not allowed until all deprecation warnings have been resolved."
    end

    test "filtered settings are migrated to db" do
      assert config_records() == []

      MixTask.migrate_to_db("test/fixtures/config/temp.secret.exs")

      config1 = ConfigDB.get_by_params(%{group: ":pleroma", key: ":first_setting"})
      config2 = ConfigDB.get_by_params(%{group: ":pleroma", key: ":second_setting"})
      config3 = ConfigDB.get_by_params(%{group: ":quack", key: ":level"})
      refute ConfigDB.get_by_params(%{group: ":pleroma", key: "Pleroma.Repo"})
      refute ConfigDB.get_by_params(%{group: ":postgrex", key: ":json_library"})
      refute ConfigDB.get_by_params(%{group: ":pleroma", key: ":database"})

      assert config1.value == [key: "value", key2: [Repo]]
      assert config2.value == [key: "value2", key2: ["Activity"]]
      assert config3.value == :info
    end

    test "config table is truncated before migration" do
      insert_config_record(:pleroma, :first_setting, key: "value", key2: ["Activity"])
      assert length(config_records()) == 1

      MixTask.migrate_to_db("test/fixtures/config/temp.secret.exs")

      config = ConfigDB.get_by_params(%{group: ":pleroma", key: ":first_setting"})
      assert config.value == [key: "value", key2: [Repo]]
    end
  end

  describe "with deletion of temp file" do
    setup do
      clear_config(:configurable_from_database, true)
      temp_file = "config/temp.exported_from_db.secret.exs"

      on_exit(fn ->
        :ok = File.rm(temp_file)
      end)

      {:ok, temp_file: temp_file}
    end

    test "settings are migrated to file and deleted from db", %{temp_file: temp_file} do
      insert_config_record(:pleroma, :setting_first, key: "value", key2: ["Activity"])
      insert_config_record(:pleroma, :setting_second, key: "value2", key2: [Repo])
      insert_config_record(:quack, :level, :info)

      MixTask.run(["migrate_from_db", "--env", "temp", "-d"])

      assert config_records() == []

      file = File.read!(temp_file)
      assert file =~ "config :pleroma, :setting_first,"
      assert file =~ "config :pleroma, :setting_second,"
      assert file =~ "config :quack, :level, :info"
    end

    test "load a settings with large values and pass to file", %{temp_file: temp_file} do
      insert(:config,
        key: :instance,
        value: [
          name: "Pleroma",
          email: "example@example.com",
          notify_email: "noreply@example.com",
          description: "A Pleroma instance, an alternative fediverse server",
          limit: 5_000,
          chat_limit: 5_000,
          remote_limit: 100_000,
          upload_limit: 16_000_000,
          avatar_upload_limit: 2_000_000,
          background_upload_limit: 4_000_000,
          banner_upload_limit: 4_000_000,
          poll_limits: %{
            max_options: 20,
            max_option_chars: 200,
            min_expiration: 0,
            max_expiration: 365 * 24 * 60 * 60
          },
          registrations_open: true,
          federating: true,
          federation_incoming_replies_max_depth: 100,
          federation_reachability_timeout_days: 7,
          federation_publisher_modules: [Pleroma.Web.ActivityPub.Publisher],
          allow_relay: true,
          public: true,
          quarantined_instances: [],
          managed_config: true,
          static_dir: "instance/static/",
          allowed_post_formats: ["text/plain", "text/html", "text/markdown", "text/bbcode"],
          autofollowed_nicknames: [],
          max_pinned_statuses: 1,
          attachment_links: false,
          max_report_comment_size: 1000,
          safe_dm_mentions: false,
          healthcheck: false,
          remote_post_retention_days: 90,
          skip_thread_containment: true,
          limit_to_local_content: :unauthenticated,
          user_bio_length: 5000,
          user_name_length: 100,
          max_account_fields: 10,
          max_remote_account_fields: 20,
          account_field_name_length: 512,
          account_field_value_length: 2048,
          external_user_synchronization: true,
          extended_nickname_format: true,
          multi_factor_authentication: [
            totp: [
              digits: 6,
              period: 30
            ],
            backup_codes: [
              number: 2,
              length: 6
            ]
          ]
        ]
      )

      MixTask.run(["migrate_from_db", "--env", "temp", "-d"])

      assert config_records() == []
      assert File.exists?(temp_file)
      {:ok, file} = File.read(temp_file)

      assert file ==
               "import Config\n\nconfig :pleroma, :instance,\n  name: \"Pleroma\",\n  email: \"example@example.com\",\n  notify_email: \"noreply@example.com\",\n  description: \"A Pleroma instance, an alternative fediverse server\",\n  limit: 5000,\n  chat_limit: 5000,\n  remote_limit: 100_000,\n  upload_limit: 16_000_000,\n  avatar_upload_limit: 2_000_000,\n  background_upload_limit: 4_000_000,\n  banner_upload_limit: 4_000_000,\n  poll_limits: %{\n    max_expiration: 31_536_000,\n    max_option_chars: 200,\n    max_options: 20,\n    min_expiration: 0\n  },\n  registrations_open: true,\n  federating: true,\n  federation_incoming_replies_max_depth: 100,\n  federation_reachability_timeout_days: 7,\n  federation_publisher_modules: [Pleroma.Web.ActivityPub.Publisher],\n  allow_relay: true,\n  public: true,\n  quarantined_instances: [],\n  managed_config: true,\n  static_dir: \"instance/static/\",\n  allowed_post_formats: [\"text/plain\", \"text/html\", \"text/markdown\", \"text/bbcode\"],\n  autofollowed_nicknames: [],\n  max_pinned_statuses: 1,\n  attachment_links: false,\n  max_report_comment_size: 1000,\n  safe_dm_mentions: false,\n  healthcheck: false,\n  remote_post_retention_days: 90,\n  skip_thread_containment: true,\n  limit_to_local_content: :unauthenticated,\n  user_bio_length: 5000,\n  user_name_length: 100,\n  max_account_fields: 10,\n  max_remote_account_fields: 20,\n  account_field_name_length: 512,\n  account_field_value_length: 2048,\n  external_user_synchronization: true,\n  extended_nickname_format: true,\n  multi_factor_authentication: [\n    totp: [digits: 6, period: 30],\n    backup_codes: [number: 2, length: 6]\n  ]\n"
    end
  end

  describe "migrate_from_db/1" do
    setup do: clear_config(:configurable_from_database, true)

    setup do
      insert_config_record(:pleroma, :setting_first, key: "value", key2: ["Activity"])
      insert_config_record(:pleroma, :setting_second, key: "value2", key2: [Repo])
      insert_config_record(:quack, :level, :info)

      path = "test/instance_static"
      file_path = Path.join(path, "temp.exported_from_db.secret.exs")

      on_exit(fn -> File.rm!(file_path) end)

      [file_path: file_path]
    end

    test "with path parameter", %{file_path: file_path} do
      MixTask.run(["migrate_from_db", "--env", "temp", "--path", Path.dirname(file_path)])

      file = File.read!(file_path)
      assert file =~ "config :pleroma, :setting_first,"
      assert file =~ "config :pleroma, :setting_second,"
      assert file =~ "config :quack, :level, :info"
    end

    test "release", %{file_path: file_path} do
      clear_config(:release, true)
      clear_config(:config_path, file_path)

      MixTask.run(["migrate_from_db", "--env", "temp"])

      file = File.read!(file_path)
      assert file =~ "config :pleroma, :setting_first,"
      assert file =~ "config :pleroma, :setting_second,"
      assert file =~ "config :quack, :level, :info"
    end
  end

  describe "operations on database config" do
    setup do: clear_config(:configurable_from_database, true)

    test "dumping a specific group" do
      insert_config_record(:pleroma, :instance, name: "Pleroma Test")

      insert_config_record(:web_push_encryption, :vapid_details,
        subject: "mailto:administrator@example.com",
        public_key:
          "BOsPL-_KjNnjj_RMvLeR3dTOrcndi4TbMR0cu56gLGfGaT5m1gXxSfRHOcC4Dd78ycQL1gdhtx13qgKHmTM5xAI",
        private_key: "Ism6FNdS31nLCA94EfVbJbDdJXCxAZ8cZiB1JQPN_t4"
      )

      MixTask.run(["dump", "pleroma"])

      assert_receive {:mix_shell, :info,
                      ["config :pleroma, :instance, [name: \"Pleroma Test\"]\r\n\r\n"]}

      refute_receive {
        :mix_shell,
        :info,
        [
          "config :web_push_encryption, :vapid_details, [subject: \"mailto:administrator@example.com\", public_key: \"BOsPL-_KjNnjj_RMvLeR3dTOrcndi4TbMR0cu56gLGfGaT5m1gXxSfRHOcC4Dd78ycQL1gdhtx13qgKHmTM5xAI\", private_key: \"Ism6FNdS31nLCA94EfVbJbDdJXCxAZ8cZiB1JQPN_t4\"]\r\n\r\n"
        ]
      }

      # Ensure operations work when using atom syntax
      MixTask.run(["dump", ":pleroma"])

      assert_receive {:mix_shell, :info,
                      ["config :pleroma, :instance, [name: \"Pleroma Test\"]\r\n\r\n"]}
    end

    test "dumping a specific key in a group" do
      insert_config_record(:pleroma, :instance, name: "Pleroma Test")
      insert_config_record(:pleroma, Pleroma.Captcha, enabled: false)

      MixTask.run(["dump", "pleroma", "Pleroma.Captcha"])

      refute_receive {:mix_shell, :info,
                      ["config :pleroma, :instance, [name: \"Pleroma Test\"]\r\n\r\n"]}

      assert_receive {:mix_shell, :info,
                      ["config :pleroma, Pleroma.Captcha, [enabled: false]\r\n\r\n"]}
    end

    test "dumps all configuration successfully" do
      insert_config_record(:pleroma, :instance, name: "Pleroma Test")
      insert_config_record(:pleroma, Pleroma.Captcha, enabled: false)

      MixTask.run(["dump"])

      assert_receive {:mix_shell, :info,
                      ["config :pleroma, :instance, [name: \"Pleroma Test\"]\r\n\r\n"]}

      assert_receive {:mix_shell, :info,
                      ["config :pleroma, Pleroma.Captcha, [enabled: false]\r\n\r\n"]}
    end
  end

  describe "when configdb disabled" do
    test "refuses to dump" do
      clear_config(:configurable_from_database, false)

      insert_config_record(:pleroma, :instance, name: "Pleroma Test")

      MixTask.run(["dump"])

      msg =
        "ConfigDB not enabled. Please check the value of :configurable_from_database in your configuration."

      assert_receive {:mix_shell, :error, [^msg]}
    end
  end

  describe "destructive operations" do
    setup do: clear_config(:configurable_from_database, true)

    setup do
      insert_config_record(:pleroma, :instance, name: "Pleroma Test")
      insert_config_record(:pleroma, Pleroma.Captcha, enabled: false)
      insert_config_record(:pleroma2, :key2, z: 1)

      assert length(config_records()) == 3

      :ok
    end

    test "deletes group of settings" do
      MixTask.run(["delete", "--force", "pleroma"])

      assert [%ConfigDB{group: :pleroma2, key: :key2}] = config_records()
    end

    test "deletes specified key" do
      MixTask.run(["delete", "--force", "pleroma", "Pleroma.Captcha"])

      assert [
               %ConfigDB{group: :pleroma, key: :instance},
               %ConfigDB{group: :pleroma2, key: :key2}
             ] = config_records()
    end

    test "resets entire config" do
      MixTask.run(["reset", "--force"])

      assert config_records() == []
    end
  end
end
