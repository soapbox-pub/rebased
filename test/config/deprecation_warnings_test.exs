defmodule Pleroma.Config.DeprecationWarningsTest do
  use ExUnit.Case, async: true
  use Pleroma.Tests.Helpers

  import ExUnit.CaptureLog

  test "check_old_mrf_config/0" do
    clear_config([:instance, :rewrite_policy], Pleroma.Web.ActivityPub.MRF.NoOpPolicy)
    clear_config([:instance, :mrf_transparency], true)
    clear_config([:instance, :mrf_transparency_exclusions], [])

    assert capture_log(fn -> Pleroma.Config.DeprecationWarnings.check_old_mrf_config() end) =~
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
             Pleroma.Config.DeprecationWarnings.move_namespace_and_warn(
               config_map,
               "Warning preface"
             )
           end) =~ "Warning preface\n error :key\n error :key2\n error :key3"

    assert Pleroma.Config.get(new_group1) == 1
    assert Pleroma.Config.get(new_group2) == 2
    assert Pleroma.Config.get(new_group3) == 3
  end
end
