defmodule Pleroma.Config.DeprecationWarningsTest do
  use ExUnit.Case, async: true
  use Pleroma.Tests.Helpers

  import ExUnit.CaptureLog

  alias Pleroma.Config
  alias Pleroma.Config.DeprecationWarnings

  test "check_old_mrf_config/0" do
    clear_config([:instance, :rewrite_policy], Pleroma.Web.ActivityPub.MRF.NoOpPolicy)
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

  describe "check_gun_pool_options/0" do
    test "await_up_timeout" do
      config = Config.get(:connections_pool)
      clear_config(:connections_pool, Keyword.put(config, :await_up_timeout, 5_000))

      assert capture_log(fn ->
               DeprecationWarnings.check_gun_pool_options()
             end) =~
               "Your config is using old setting name `await_up_timeout` instead of `connect_timeout`"
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
end
