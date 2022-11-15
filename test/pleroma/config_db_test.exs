# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ConfigDBTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory
  alias Pleroma.ConfigDB

  test "get_by_params/1" do
    config = insert(:config)
    insert(:config)

    assert config == ConfigDB.get_by_params(%{group: config.group, key: config.key})
  end

  test "get_all_as_keyword/0" do
    saved = insert(:config)
    insert(:config, group: ":goose", key: ":level", value: :info)
    insert(:config, group: ":goose", key: ":meta", value: [:none])

    insert(:config,
      group: ":goose",
      key: ":webhook_url",
      value: "https://gander.com/"
    )

    config = ConfigDB.get_all_as_keyword()

    assert config[:pleroma] == [
             {saved.key, saved.value}
           ]

    assert config[:goose][:level] == :info
    assert config[:goose][:meta] == [:none]
    assert config[:goose][:webhook_url] == "https://gander.com/"
  end

  describe "update_or_create/1" do
    test "common" do
      config = insert(:config)
      key2 = :another_key

      params = [
        %{group: :pleroma, key: key2, value: "another_value"},
        %{group: :pleroma, key: config.key, value: [a: 1, b: 2, c: "new_value"]}
      ]

      assert Repo.all(ConfigDB) |> length() == 1

      Enum.each(params, &ConfigDB.update_or_create(&1))

      assert Repo.all(ConfigDB) |> length() == 2

      config1 = ConfigDB.get_by_params(%{group: config.group, key: config.key})
      config2 = ConfigDB.get_by_params(%{group: :pleroma, key: key2})

      assert config1.value == [a: 1, b: 2, c: "new_value"]
      assert config2.value == "another_value"
    end

    test "partial update" do
      config = insert(:config, value: [key1: "val1", key2: :val2])

      {:ok, config} =
        ConfigDB.update_or_create(%{
          group: config.group,
          key: config.key,
          value: [key1: :val1, key3: :val3]
        })

      updated = ConfigDB.get_by_params(%{group: config.group, key: config.key})

      assert config.value == updated.value
      assert updated.value[:key1] == :val1
      assert updated.value[:key2] == :val2
      assert updated.value[:key3] == :val3
    end

    test "deep merge" do
      config = insert(:config, value: [key1: "val1", key2: [k1: :v1, k2: "v2"]])

      {:ok, config} =
        ConfigDB.update_or_create(%{
          group: config.group,
          key: config.key,
          value: [key1: :val1, key2: [k2: :v2, k3: :v3], key3: :val3]
        })

      updated = ConfigDB.get_by_params(%{group: config.group, key: config.key})

      assert config.value == updated.value
      assert updated.value[:key1] == :val1
      assert updated.value[:key2] == [k1: :v1, k2: :v2, k3: :v3]
      assert updated.value[:key3] == :val3
    end

    test "only full update for some keys" do
      config1 = insert(:config, key: :ecto_repos, value: [repo: Pleroma.Repo])

      config2 = insert(:config, group: :cors_plug, key: :max_age, value: 18)

      {:ok, _config} =
        ConfigDB.update_or_create(%{
          group: config1.group,
          key: config1.key,
          value: [another_repo: [Pleroma.Repo]]
        })

      {:ok, _config} =
        ConfigDB.update_or_create(%{
          group: config2.group,
          key: config2.key,
          value: 777
        })

      updated1 = ConfigDB.get_by_params(%{group: config1.group, key: config1.key})
      updated2 = ConfigDB.get_by_params(%{group: config2.group, key: config2.key})

      assert updated1.value == [another_repo: [Pleroma.Repo]]
      assert updated2.value == 777
    end

    test "full update if value is not keyword" do
      config =
        insert(:config,
          group: ":tesla",
          key: ":adapter",
          value: Tesla.Adapter.Hackney
        )

      {:ok, _config} =
        ConfigDB.update_or_create(%{
          group: config.group,
          key: config.key,
          value: Tesla.Adapter.Httpc
        })

      updated = ConfigDB.get_by_params(%{group: config.group, key: config.key})

      assert updated.value == Tesla.Adapter.Httpc
    end

    test "only full update for some subkeys" do
      config1 =
        insert(:config,
          key: ":emoji",
          value: [groups: [a: 1, b: 2], key: [a: 1]]
        )

      config2 =
        insert(:config,
          key: ":assets",
          value: [mascots: [a: 1, b: 2], key: [a: 1]]
        )

      {:ok, _config} =
        ConfigDB.update_or_create(%{
          group: config1.group,
          key: config1.key,
          value: [groups: [c: 3, d: 4], key: [b: 2]]
        })

      {:ok, _config} =
        ConfigDB.update_or_create(%{
          group: config2.group,
          key: config2.key,
          value: [mascots: [c: 3, d: 4], key: [b: 2]]
        })

      updated1 = ConfigDB.get_by_params(%{group: config1.group, key: config1.key})
      updated2 = ConfigDB.get_by_params(%{group: config2.group, key: config2.key})

      assert updated1.value == [groups: [c: 3, d: 4], key: [a: 1, b: 2]]
      assert updated2.value == [mascots: [c: 3, d: 4], key: [a: 1, b: 2]]
    end
  end

  describe "delete/1" do
    test "error on deleting non existing setting" do
      {:error, error} = ConfigDB.delete(%{group: ":pleroma", key: ":key"})
      assert error =~ "Config with params %{group: \":pleroma\", key: \":key\"} not found"
    end

    test "full delete" do
      config = insert(:config)
      {:ok, deleted} = ConfigDB.delete(%{group: config.group, key: config.key})
      assert Ecto.get_meta(deleted, :state) == :deleted
      refute ConfigDB.get_by_params(%{group: config.group, key: config.key})
    end

    test "partial subkeys delete" do
      config = insert(:config, value: [groups: [a: 1, b: 2], key: [a: 1]])

      {:ok, deleted} =
        ConfigDB.delete(%{group: config.group, key: config.key, subkeys: [":groups"]})

      assert Ecto.get_meta(deleted, :state) == :loaded

      assert deleted.value == [key: [a: 1]]

      updated = ConfigDB.get_by_params(%{group: config.group, key: config.key})

      assert updated.value == deleted.value
    end

    test "full delete if remaining value after subkeys deletion is empty list" do
      config = insert(:config, value: [groups: [a: 1, b: 2]])

      {:ok, deleted} =
        ConfigDB.delete(%{group: config.group, key: config.key, subkeys: [":groups"]})

      assert Ecto.get_meta(deleted, :state) == :deleted

      refute ConfigDB.get_by_params(%{group: config.group, key: config.key})
    end
  end

  describe "to_elixir_types/1" do
    test "string" do
      assert ConfigDB.to_elixir_types("value as string") == "value as string"
    end

    test "boolean" do
      assert ConfigDB.to_elixir_types(false) == false
    end

    test "nil" do
      assert ConfigDB.to_elixir_types(nil) == nil
    end

    test "integer" do
      assert ConfigDB.to_elixir_types(150) == 150
    end

    test "atom" do
      assert ConfigDB.to_elixir_types(":atom") == :atom
    end

    test "ssl options" do
      assert ConfigDB.to_elixir_types([":tlsv1", ":tlsv1.1", ":tlsv1.2", ":tlsv1.3"]) == [
               :tlsv1,
               :"tlsv1.1",
               :"tlsv1.2",
               :"tlsv1.3"
             ]
    end

    test "pleroma module" do
      assert ConfigDB.to_elixir_types("Pleroma.Bookmark") == Pleroma.Bookmark
    end

    test "pleroma string" do
      assert ConfigDB.to_elixir_types("Pleroma") == "Pleroma"
    end

    test "phoenix module" do
      assert ConfigDB.to_elixir_types("Phoenix.Socket.V1.JSONSerializer") ==
               Phoenix.Socket.V1.JSONSerializer
    end

    test "tesla module" do
      assert ConfigDB.to_elixir_types("Tesla.Adapter.Hackney") == Tesla.Adapter.Hackney
    end

    test "ExSyslogger module" do
      assert ConfigDB.to_elixir_types("ExSyslogger") == ExSyslogger
    end

    test "Swoosh.Adapters modules" do
      assert ConfigDB.to_elixir_types("Swoosh.Adapters.SMTP") == Swoosh.Adapters.SMTP
      assert ConfigDB.to_elixir_types("Swoosh.Adapters.AmazonSES") == Swoosh.Adapters.AmazonSES
    end

    test "sigil" do
      assert ConfigDB.to_elixir_types("~r[comp[lL][aA][iI][nN]er]") == ~r/comp[lL][aA][iI][nN]er/
    end

    test "link sigil" do
      assert ConfigDB.to_elixir_types("~r/https:\/\/example.com/") == ~r/https:\/\/example.com/
    end

    test "link sigil with um modifiers" do
      assert ConfigDB.to_elixir_types("~r/https:\/\/example.com/um") ==
               ~r/https:\/\/example.com/um
    end

    test "link sigil with i modifier" do
      assert ConfigDB.to_elixir_types("~r/https:\/\/example.com/i") == ~r/https:\/\/example.com/i
    end

    test "link sigil with s modifier" do
      assert ConfigDB.to_elixir_types("~r/https:\/\/example.com/s") == ~r/https:\/\/example.com/s
    end

    test "raise if valid delimiter not found" do
      assert_raise ArgumentError, "valid delimiter for Regex expression not found", fn ->
        ConfigDB.to_elixir_types("~r/https://[]{}<>\"'()|example.com/s")
      end
    end

    test "2 child tuple" do
      assert ConfigDB.to_elixir_types(%{"tuple" => ["v1", ":v2"]}) == {"v1", :v2}
    end

    test "proxy tuple with localhost" do
      assert ConfigDB.to_elixir_types(%{
               "tuple" => [":proxy_url", %{"tuple" => [":socks5", "localhost", 1234]}]
             }) == {:proxy_url, {:socks5, :localhost, 1234}}
    end

    test "proxy tuple with domain" do
      assert ConfigDB.to_elixir_types(%{
               "tuple" => [":proxy_url", %{"tuple" => [":socks5", "domain.com", 1234]}]
             }) == {:proxy_url, {:socks5, 'domain.com', 1234}}
    end

    test "proxy tuple with ip" do
      assert ConfigDB.to_elixir_types(%{
               "tuple" => [":proxy_url", %{"tuple" => [":socks5", "127.0.0.1", 1234]}]
             }) == {:proxy_url, {:socks5, {127, 0, 0, 1}, 1234}}
    end

    test "tuple with n childs" do
      assert ConfigDB.to_elixir_types(%{
               "tuple" => [
                 "v1",
                 ":v2",
                 "Pleroma.Bookmark",
                 150,
                 false,
                 "Phoenix.Socket.V1.JSONSerializer"
               ]
             }) == {"v1", :v2, Pleroma.Bookmark, 150, false, Phoenix.Socket.V1.JSONSerializer}
    end

    test "map with string key" do
      assert ConfigDB.to_elixir_types(%{"key" => "value"}) == %{"key" => "value"}
    end

    test "map with atom key" do
      assert ConfigDB.to_elixir_types(%{":key" => "value"}) == %{key: "value"}
    end

    test "list of strings" do
      assert ConfigDB.to_elixir_types(["v1", "v2", "v3"]) == ["v1", "v2", "v3"]
    end

    test "list of modules" do
      assert ConfigDB.to_elixir_types(["Pleroma.Repo", "Pleroma.Activity"]) == [
               Pleroma.Repo,
               Pleroma.Activity
             ]
    end

    test "list of atoms" do
      assert ConfigDB.to_elixir_types([":v1", ":v2", ":v3"]) == [:v1, :v2, :v3]
    end

    test "list of mixed values" do
      assert ConfigDB.to_elixir_types([
               "v1",
               ":v2",
               "Pleroma.Repo",
               "Phoenix.Socket.V1.JSONSerializer",
               15,
               false
             ]) == [
               "v1",
               :v2,
               Pleroma.Repo,
               Phoenix.Socket.V1.JSONSerializer,
               15,
               false
             ]
    end

    test "simple keyword" do
      assert ConfigDB.to_elixir_types([%{"tuple" => [":key", "value"]}]) == [key: "value"]
    end

    test "keyword" do
      assert ConfigDB.to_elixir_types([
               %{"tuple" => [":types", "Pleroma.PostgresTypes"]},
               %{"tuple" => [":telemetry_event", ["Pleroma.Repo.Instrumenter"]]},
               %{"tuple" => [":migration_lock", nil]},
               %{"tuple" => [":key1", 150]},
               %{"tuple" => [":key2", "string"]}
             ]) == [
               types: Pleroma.PostgresTypes,
               telemetry_event: [Pleroma.Repo.Instrumenter],
               migration_lock: nil,
               key1: 150,
               key2: "string"
             ]
    end

    test "trandformed keyword" do
      assert ConfigDB.to_elixir_types(a: 1, b: 2, c: "string") == [a: 1, b: 2, c: "string"]
    end

    test "complex keyword with nested mixed childs" do
      assert ConfigDB.to_elixir_types([
               %{"tuple" => [":uploader", "Pleroma.Uploaders.Local"]},
               %{"tuple" => [":filters", ["Pleroma.Upload.Filter.Dedupe"]]},
               %{"tuple" => [":link_name", true]},
               %{"tuple" => [":proxy_remote", false]},
               %{"tuple" => [":common_map", %{":key" => "value"}]},
               %{
                 "tuple" => [
                   ":proxy_opts",
                   [
                     %{"tuple" => [":redirect_on_failure", false]},
                     %{"tuple" => [":max_body_length", 1_048_576]},
                     %{
                       "tuple" => [
                         ":http",
                         [
                           %{"tuple" => [":follow_redirect", true]},
                           %{"tuple" => [":pool", ":upload"]}
                         ]
                       ]
                     }
                   ]
                 ]
               }
             ]) == [
               uploader: Pleroma.Uploaders.Local,
               filters: [Pleroma.Upload.Filter.Dedupe],
               link_name: true,
               proxy_remote: false,
               common_map: %{key: "value"},
               proxy_opts: [
                 redirect_on_failure: false,
                 max_body_length: 1_048_576,
                 http: [
                   follow_redirect: true,
                   pool: :upload
                 ]
               ]
             ]
    end

    test "common keyword" do
      assert ConfigDB.to_elixir_types([
               %{"tuple" => [":level", ":warn"]},
               %{"tuple" => [":meta", [":all"]]},
               %{"tuple" => [":path", ""]},
               %{"tuple" => [":val", nil]},
               %{"tuple" => [":webhook_url", "https://hooks.slack.com/services/YOUR-KEY-HERE"]}
             ]) == [
               level: :warn,
               meta: [:all],
               path: "",
               val: nil,
               webhook_url: "https://hooks.slack.com/services/YOUR-KEY-HERE"
             ]
    end

    test "complex keyword with sigil" do
      assert ConfigDB.to_elixir_types([
               %{"tuple" => [":federated_timeline_removal", []]},
               %{"tuple" => [":reject", ["~r/comp[lL][aA][iI][nN]er/"]]},
               %{"tuple" => [":replace", []]}
             ]) == [
               federated_timeline_removal: [],
               reject: [~r/comp[lL][aA][iI][nN]er/],
               replace: []
             ]
    end

    test "complex keyword with tuples with more than 2 values" do
      assert ConfigDB.to_elixir_types([
               %{
                 "tuple" => [
                   ":http",
                   [
                     %{
                       "tuple" => [
                         ":key1",
                         [
                           %{
                             "tuple" => [
                               ":_",
                               [
                                 %{
                                   "tuple" => [
                                     "/api/v1/streaming",
                                     "Pleroma.Web.MastodonAPI.WebsocketHandler",
                                     []
                                   ]
                                 },
                                 %{
                                   "tuple" => [
                                     "/websocket",
                                     "Phoenix.Endpoint.CowboyWebSocket",
                                     %{
                                       "tuple" => [
                                         "Phoenix.Transports.WebSocket",
                                         %{
                                           "tuple" => [
                                             "Pleroma.Web.Endpoint",
                                             "Pleroma.Web.UserSocket",
                                             []
                                           ]
                                         }
                                       ]
                                     }
                                   ]
                                 },
                                 %{
                                   "tuple" => [
                                     ":_",
                                     "Phoenix.Endpoint.Cowboy2Handler",
                                     %{"tuple" => ["Pleroma.Web.Endpoint", []]}
                                   ]
                                 }
                               ]
                             ]
                           }
                         ]
                       ]
                     }
                   ]
                 ]
               }
             ]) == [
               http: [
                 key1: [
                   {:_,
                    [
                      {"/api/v1/streaming", Pleroma.Web.MastodonAPI.WebsocketHandler, []},
                      {"/websocket", Phoenix.Endpoint.CowboyWebSocket,
                       {Phoenix.Transports.WebSocket,
                        {Pleroma.Web.Endpoint, Pleroma.Web.UserSocket, []}}},
                      {:_, Phoenix.Endpoint.Cowboy2Handler, {Pleroma.Web.Endpoint, []}}
                    ]}
                 ]
               ]
             ]
    end
  end
end
