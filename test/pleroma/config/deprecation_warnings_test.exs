# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.DeprecationWarningsTest do
  use ExUnit.Case
  use Pleroma.Tests.Helpers

  import ExUnit.CaptureLog

  alias Pleroma.Config
  alias Pleroma.Config.DeprecationWarnings

  describe "filter exiftool" do
    test "gives warning when still used" do
      clear_config(
        [Pleroma.Upload, :filters],
        [Pleroma.Upload.Filter.Exiftool]
      )

      assert capture_log(fn -> DeprecationWarnings.check_exiftool_filter() end) =~
               """
               !!!DEPRECATION WARNING!!!
               Your config is using Exiftool as a filter instead of Exiftool.StripLocation. This should work for now, but you are advised to change to the new configuration to prevent possible issues later:

               ```
               config :pleroma, Pleroma.Upload,
                 filters: [Pleroma.Upload.Filter.Exiftool]
               ```

               Is now


               ```
               config :pleroma, Pleroma.Upload,
                 filters: [Pleroma.Upload.Filter.Exiftool.StripLocation]
               ```
               """
    end

    test "changes setting to exiftool strip location" do
      clear_config(
        [Pleroma.Upload, :filters],
        [Pleroma.Upload.Filter.Exiftool, Pleroma.Upload.Filter.Exiftool.ReadDescription]
      )

      expected_config = [
        Pleroma.Upload.Filter.Exiftool.StripLocation,
        Pleroma.Upload.Filter.Exiftool.ReadDescription
      ]

      capture_log(fn -> DeprecationWarnings.warn() end)

      assert Config.get([Pleroma.Upload]) |> Keyword.get(:filters, []) == expected_config
    end

    test "doesn't give a warning with correct config" do
      clear_config(
        [Pleroma.Upload, :filters],
        [
          Pleroma.Upload.Filter.Exiftool.StripLocation,
          Pleroma.Upload.Filter.Exiftool.ReadDescription
        ]
      )

      assert capture_log(fn -> DeprecationWarnings.check_exiftool_filter() end) == ""
    end
  end

  describe "simple policy tuples" do
    test "gives warning when there are still strings" do
      clear_config([:mrf_simple],
        media_removal: ["some.removal"],
        media_nsfw: ["some.nsfw"],
        federated_timeline_removal: ["some.tl.removal"],
        report_removal: ["some.report.removal"],
        reject: ["some.reject"],
        followers_only: ["some.followers.only"],
        accept: ["some.accept"],
        avatar_removal: ["some.avatar.removal"],
        banner_removal: ["some.banner.removal"],
        reject_deletes: ["some.reject.deletes"]
      )

      assert capture_log(fn -> DeprecationWarnings.check_simple_policy_tuples() end) =~
               """
               !!!DEPRECATION WARNING!!!
               Your config is using strings in the SimplePolicy configuration instead of tuples. They should work for now, but you are advised to change to the new configuration to prevent possible issues later:

               ```
               config :pleroma, :mrf_simple,
                 media_removal: ["instance.tld"],
                 media_nsfw: ["instance.tld"],
                 federated_timeline_removal: ["instance.tld"],
                 report_removal: ["instance.tld"],
                 reject: ["instance.tld"],
                 followers_only: ["instance.tld"],
                 accept: ["instance.tld"],
                 avatar_removal: ["instance.tld"],
                 banner_removal: ["instance.tld"],
                 reject_deletes: ["instance.tld"]
               ```

               Is now


               ```
               config :pleroma, :mrf_simple,
                 media_removal: [{"instance.tld", "Reason for media removal"}],
                 media_nsfw: [{"instance.tld", "Reason for media nsfw"}],
                 federated_timeline_removal: [{"instance.tld", "Reason for federated timeline removal"}],
                 report_removal: [{"instance.tld", "Reason for report removal"}],
                 reject: [{"instance.tld", "Reason for reject"}],
                 followers_only: [{"instance.tld", "Reason for followers only"}],
                 accept: [{"instance.tld", "Reason for accept"}],
                 avatar_removal: [{"instance.tld", "Reason for avatar removal"}],
                 banner_removal: [{"instance.tld", "Reason for banner removal"}],
                 reject_deletes: [{"instance.tld", "Reason for reject deletes"}]
               ```
               """
    end

    test "transforms config to tuples" do
      clear_config([:mrf_simple],
        media_removal: ["some.removal", {"some.other.instance", "Some reason"}]
      )

      expected_config = [
        {:media_removal, [{"some.removal", ""}, {"some.other.instance", "Some reason"}]}
      ]

      capture_log(fn -> DeprecationWarnings.warn() end)

      assert Config.get([:mrf_simple]) == expected_config
    end

    test "doesn't give a warning with correct config" do
      clear_config([:mrf_simple],
        media_removal: [{"some.removal", ""}, {"some.other.instance", "Some reason"}]
      )

      assert capture_log(fn -> DeprecationWarnings.check_simple_policy_tuples() end) == ""
    end
  end

  describe "quarantined_instances tuples" do
    test "gives warning when there are still strings" do
      clear_config([:instance, :quarantined_instances], [
        {"domain.com", "some reason"},
        "somedomain.tld"
      ])

      assert capture_log(fn -> DeprecationWarnings.check_quarantined_instances_tuples() end) =~
               """
               !!!DEPRECATION WARNING!!!
               Your config is using strings in the quarantined_instances configuration instead of tuples. They should work for now, but you are advised to change to the new configuration to prevent possible issues later:

               ```
               config :pleroma, :instance,
                 quarantined_instances: ["instance.tld"]
               ```

               Is now


               ```
               config :pleroma, :instance,
                 quarantined_instances: [{"instance.tld", "Reason for quarantine"}]
               ```
               """
    end

    test "transforms config to tuples" do
      clear_config([:instance, :quarantined_instances], [
        {"domain.com", "some reason"},
        "some.tld"
      ])

      expected_config = [{"domain.com", "some reason"}, {"some.tld", ""}]

      capture_log(fn -> DeprecationWarnings.warn() end)

      assert Config.get([:instance, :quarantined_instances]) == expected_config
    end

    test "doesn't give a warning with correct config" do
      clear_config([:instance, :quarantined_instances], [
        {"domain.com", "some reason"},
        {"some.tld", ""}
      ])

      assert capture_log(fn -> DeprecationWarnings.check_quarantined_instances_tuples() end) == ""
    end
  end

  describe "transparency_exclusions tuples" do
    test "gives warning when there are still strings" do
      clear_config([:mrf, :transparency_exclusions], [
        {"domain.com", "some reason"},
        "somedomain.tld"
      ])

      assert capture_log(fn -> DeprecationWarnings.check_transparency_exclusions_tuples() end) =~
               """
               !!!DEPRECATION WARNING!!!
               Your config is using strings in the transparency_exclusions configuration instead of tuples. They should work for now, but you are advised to change to the new configuration to prevent possible issues later:

               ```
               config :pleroma, :mrf,
                 transparency_exclusions: ["instance.tld"]
               ```

               Is now


               ```
               config :pleroma, :mrf,
                 transparency_exclusions: [{"instance.tld", "Reason to exlude transparency"}]
               ```
               """
    end

    test "transforms config to tuples" do
      clear_config([:mrf, :transparency_exclusions], [
        {"domain.com", "some reason"},
        "some.tld"
      ])

      expected_config = [{"domain.com", "some reason"}, {"some.tld", ""}]

      capture_log(fn -> DeprecationWarnings.warn() end)

      assert Config.get([:mrf, :transparency_exclusions]) == expected_config
    end

    test "doesn't give a warning with correct config" do
      clear_config([:mrf, :transparency_exclusions], [
        {"domain.com", "some reason"},
        {"some.tld", ""}
      ])

      assert capture_log(fn -> DeprecationWarnings.check_transparency_exclusions_tuples() end) ==
               ""
    end
  end

  test "check_old_mrf_config/0" do
    clear_config([:instance, :rewrite_policy], [])
    clear_config([:instance, :mrf_transparency], true)
    clear_config([:instance, :mrf_transparency_exclusions], [])

    assert capture_log(fn -> DeprecationWarnings.check_old_mrf_config() end) =~
             """
             !!!DEPRECATION WARNING!!!
             Your config is using old namespaces for MRF configuration. They should work for now, but you are advised to change to new namespaces to prevent possible issues later:

             * `config :pleroma, :instance, rewrite_policy` is now `config :pleroma, :mrf, policies`
             * `config :pleroma, :instance, mrf_transparency` is now `config :pleroma, :mrf, transparency`
             * `config :pleroma, :instance, mrf_transparency_exclusions` is now `config :pleroma, :mrf, transparency_exclusions`
             """
  end

  test "move_namespace_and_warn/2" do
    old_group1 = [:group, :key]
    old_group2 = [:group, :key2]
    old_group3 = [:group, :key3]

    new_group1 = [:another_group, :key4]
    new_group2 = [:another_group, :key5]
    new_group3 = [:another_group, :key6]

    clear_config(old_group1, 1)
    clear_config(old_group2, 2)
    clear_config(old_group3, 3)

    clear_config(new_group1)
    clear_config(new_group2)
    clear_config(new_group3)

    config_map = [
      {old_group1, new_group1, "\n error :key"},
      {old_group2, new_group2, "\n error :key2"},
      {old_group3, new_group3, "\n error :key3"}
    ]

    assert capture_log(fn ->
             DeprecationWarnings.move_namespace_and_warn(
               config_map,
               "Warning preface"
             )
           end) =~ "Warning preface\n error :key\n error :key2\n error :key3"

    assert Config.get(new_group1) == 1
    assert Config.get(new_group2) == 2
    assert Config.get(new_group3) == 3
  end

  test "check_media_proxy_whitelist_config/0" do
    clear_config([:media_proxy, :whitelist], ["https://example.com", "example2.com"])

    assert capture_log(fn ->
             DeprecationWarnings.check_media_proxy_whitelist_config()
           end) =~ "Your config is using old format (only domain) for MediaProxy whitelist option"
  end

  test "check_welcome_message_config/0" do
    clear_config([:instance, :welcome_user_nickname], "LainChan")

    assert capture_log(fn ->
             DeprecationWarnings.check_welcome_message_config()
           end) =~ "Your config is using the old namespace for Welcome messages configuration."
  end

  test "check_hellthread_threshold/0" do
    clear_config([:mrf_hellthread, :threshold], 16)

    assert capture_log(fn ->
             DeprecationWarnings.check_hellthread_threshold()
           end) =~ "You are using the old configuration mechanism for the hellthread filter."
  end

  test "check_activity_expiration_config/0" do
    clear_config([Pleroma.ActivityExpiration], enabled: true)

    assert capture_log(fn ->
             DeprecationWarnings.check_activity_expiration_config()
           end) =~ "Your config is using old namespace for activity expiration configuration."
  end

  test "check_uploders_s3_public_endpoint/0" do
    clear_config([Pleroma.Uploaders.S3], public_endpoint: "https://fake.amazonaws.com/bucket/")

    assert capture_log(fn ->
             DeprecationWarnings.check_uploders_s3_public_endpoint()
           end) =~
             "Your config is using the old setting for controlling the URL of media uploaded to your S3 bucket."
  end

  describe "check_gun_pool_options/0" do
    test "await_up_timeout" do
      config = Config.get(:connections_pool)
      clear_config(:connections_pool, Keyword.put(config, :await_up_timeout, 5_000))

      assert capture_log(fn ->
               DeprecationWarnings.check_gun_pool_options()
             end) =~
               "Your config is using old setting `config :pleroma, :connections_pool, await_up_timeout`."
    end

    test "pool timeout" do
      old_config = [
        federation: [
          size: 50,
          max_waiting: 10,
          timeout: 10_000
        ],
        media: [
          size: 50,
          max_waiting: 10,
          timeout: 10_000
        ],
        upload: [
          size: 25,
          max_waiting: 5,
          timeout: 15_000
        ],
        default: [
          size: 10,
          max_waiting: 2,
          timeout: 5_000
        ]
      ]

      clear_config(:pools, old_config)

      assert capture_log(fn ->
               DeprecationWarnings.check_gun_pool_options()
             end) =~
               "Your config is using old setting name `timeout` instead of `recv_timeout` in pool settings"
    end
  end

  test "check_old_chat_shoutbox/0" do
    clear_config([:instance, :chat_limit], 1_000)
    clear_config([:chat, :enabled], true)

    assert capture_log(fn ->
             DeprecationWarnings.check_old_chat_shoutbox()
           end) =~
             "Your config is using the old namespace for the Shoutbox configuration."
  end
end
