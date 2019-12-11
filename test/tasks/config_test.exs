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

  test "load a settings with large values and pass to file", %{temp_file: temp_file} do
    Config.create(%{
      group: "pleroma",
      key: ":instance",
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
        rewrite_policy: Pleroma.Web.ActivityPub.MRF.NoOpPolicy,
        public: true,
        quarantined_instances: [],
        managed_config: true,
        static_dir: "instance/static/",
        allowed_post_formats: ["text/plain", "text/html", "text/markdown", "text/bbcode"],
        mrf_transparency: true,
        mrf_transparency_exclusions: [],
        autofollowed_nicknames: [],
        max_pinned_statuses: 1,
        no_attachment_links: true,
        welcome_user_nickname: nil,
        welcome_message: nil,
        max_report_comment_size: 1000,
        safe_dm_mentions: false,
        healthcheck: false,
        remote_post_retention_days: 90,
        skip_thread_containment: true,
        limit_to_local_content: :unauthenticated,
        dynamic_configuration: false,
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
            # digits 6 or 8
            digits: 6,
            period: 30
          ],
          backup_codes: [
            number: 2,
            length: 6
          ]
        ]
      ]
    })

    Mix.Tasks.Pleroma.Config.run(["migrate_from_db", "temp", "true"])

    assert Repo.all(Config) == []
    assert File.exists?(temp_file)
    {:ok, file} = File.read(temp_file)

    assert file ==
             "use Mix.Config\n\nconfig :pleroma, :instance,\n  name: \"Pleroma\",\n  email: \"example@example.com\",\n  notify_email: \"noreply@example.com\",\n  description: \"A Pleroma instance, an alternative fediverse server\",\n  limit: 5000,\n  chat_limit: 5000,\n  remote_limit: 100_000,\n  upload_limit: 16_000_000,\n  avatar_upload_limit: 2_000_000,\n  background_upload_limit: 4_000_000,\n  banner_upload_limit: 4_000_000,\n  poll_limits: %{\n    max_expiration: 31_536_000,\n    max_option_chars: 200,\n    max_options: 20,\n    min_expiration: 0\n  },\n  registrations_open: true,\n  federating: true,\n  federation_incoming_replies_max_depth: 100,\n  federation_reachability_timeout_days: 7,\n  federation_publisher_modules: [Pleroma.Web.ActivityPub.Publisher],\n  allow_relay: true,\n  rewrite_policy: Pleroma.Web.ActivityPub.MRF.NoOpPolicy,\n  public: true,\n  quarantined_instances: [],\n  managed_config: true,\n  static_dir: \"instance/static/\",\n  allowed_post_formats: [\"text/plain\", \"text/html\", \"text/markdown\", \"text/bbcode\"],\n  mrf_transparency: true,\n  mrf_transparency_exclusions: [],\n  autofollowed_nicknames: [],\n  max_pinned_statuses: 1,\n  no_attachment_links: true,\n  welcome_user_nickname: nil,\n  welcome_message: nil,\n  max_report_comment_size: 1000,\n  safe_dm_mentions: false,\n  healthcheck: false,\n  remote_post_retention_days: 90,\n  skip_thread_containment: true,\n  limit_to_local_content: :unauthenticated,\n  dynamic_configuration: false,\n  user_bio_length: 5000,\n  user_name_length: 100,\n  max_account_fields: 10,\n  max_remote_account_fields: 20,\n  account_field_name_length: 512,\n  account_field_value_length: 2048,\n  external_user_synchronization: true,\n  extended_nickname_format: true,\n  multi_factor_authentication: [\n    totp: [digits: 6, period: 30],\n    backup_codes: [number: 2, length: 6]\n  ]\n"
  end
end
