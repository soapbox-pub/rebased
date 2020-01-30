# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ConfigDBTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory
  alias Pleroma.ConfigDB

  test "get_by_key/1" do
    config = insert(:config)
    insert(:config)

    assert config == ConfigDB.get_by_params(%{group: config.group, key: config.key})
  end

  test "create/1" do
    {:ok, config} = ConfigDB.create(%{group: ":pleroma", key: ":some_key", value: "some_value"})
    assert config == ConfigDB.get_by_params(%{group: ":pleroma", key: ":some_key"})
  end

  test "update/1" do
    config = insert(:config)
    {:ok, updated} = ConfigDB.update(config, %{value: "some_value"})
    loaded = ConfigDB.get_by_params(%{group: config.group, key: config.key})
    assert loaded == updated
  end

  test "get_all_as_keyword/0" do
    saved = insert(:config)
    insert(:config, group: ":quack", key: ":level", value: ConfigDB.to_binary(:info))
    insert(:config, group: ":quack", key: ":meta", value: ConfigDB.to_binary([:none]))

    insert(:config,
      group: ":quack",
      key: ":webhook_url",
      value: ConfigDB.to_binary("https://hooks.slack.com/services/KEY/some_val")
    )

    config = ConfigDB.get_all_as_keyword()

    assert config[:pleroma] == [
             {ConfigDB.from_string(saved.key), ConfigDB.from_binary(saved.value)}
           ]

    assert config[:quack] == [
             level: :info,
             meta: [:none],
             webhook_url: "https://hooks.slack.com/services/KEY/some_val"
           ]
  end

  describe "update_or_create/1" do
    test "common" do
      config = insert(:config)
      key2 = "another_key"

      params = [
        %{group: "pleroma", key: key2, value: "another_value"},
        %{group: config.group, key: config.key, value: "new_value"}
      ]

      assert Repo.all(ConfigDB) |> length() == 1

      Enum.each(params, &ConfigDB.update_or_create(&1))

      assert Repo.all(ConfigDB) |> length() == 2

      config1 = ConfigDB.get_by_params(%{group: config.group, key: config.key})
      config2 = ConfigDB.get_by_params(%{group: "pleroma", key: key2})

      assert config1.value == ConfigDB.transform("new_value")
      assert config2.value == ConfigDB.transform("another_value")
    end

    test "partial update" do
      config = insert(:config, value: ConfigDB.to_binary(key1: "val1", key2: :val2))

      {:ok, _config} =
        ConfigDB.update_or_create(%{
          group: config.group,
          key: config.key,
          value: [key1: :val1, key3: :val3]
        })

      updated = ConfigDB.get_by_params(%{group: config.group, key: config.key})

      value = ConfigDB.from_binary(updated.value)
      assert length(value) == 3
      assert value[:key1] == :val1
      assert value[:key2] == :val2
      assert value[:key3] == :val3
    end

    test "deep merge" do
      config = insert(:config, value: ConfigDB.to_binary(key1: "val1", key2: [k1: :v1, k2: "v2"]))

      {:ok, config} =
        ConfigDB.update_or_create(%{
          group: config.group,
          key: config.key,
          value: [key1: :val1, key2: [k2: :v2, k3: :v3], key3: :val3]
        })

      updated = ConfigDB.get_by_params(%{group: config.group, key: config.key})

      assert config.value == updated.value

      value = ConfigDB.from_binary(updated.value)
      assert value[:key1] == :val1
      assert value[:key2] == [k1: :v1, k2: :v2, k3: :v3]
      assert value[:key3] == :val3
    end

    test "only full update for some keys" do
      config1 = insert(:config, key: ":ecto_repos", value: ConfigDB.to_binary(repo: Pleroma.Repo))

      config2 =
        insert(:config, group: ":cors_plug", key: ":max_age", value: ConfigDB.to_binary(18))

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

      assert ConfigDB.from_binary(updated1.value) == [another_repo: [Pleroma.Repo]]
      assert ConfigDB.from_binary(updated2.value) == 777
    end

    test "full update if value is not keyword" do
      config =
        insert(:config,
          group: ":tesla",
          key: ":adapter",
          value: ConfigDB.to_binary(Tesla.Adapter.Hackney)
        )

      {:ok, _config} =
        ConfigDB.update_or_create(%{
          group: config.group,
          key: config.key,
          value: Tesla.Adapter.Httpc
        })

      updated = ConfigDB.get_by_params(%{group: config.group, key: config.key})

      assert ConfigDB.from_binary(updated.value) == Tesla.Adapter.Httpc
    end

    test "only full update for some subkeys" do
      config1 =
        insert(:config,
          key: ":emoji",
          value: ConfigDB.to_binary(groups: [a: 1, b: 2], key: [a: 1])
        )

      config2 =
        insert(:config,
          key: ":assets",
          value: ConfigDB.to_binary(mascots: [a: 1, b: 2], key: [a: 1])
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

      assert ConfigDB.from_binary(updated1.value) == [groups: [c: 3, d: 4], key: [a: 1, b: 2]]
      assert ConfigDB.from_binary(updated2.value) == [mascots: [c: 3, d: 4], key: [a: 1, b: 2]]
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
      config = insert(:config, value: ConfigDB.to_binary(groups: [a: 1, b: 2], key: [a: 1]))

      {:ok, deleted} =
        ConfigDB.delete(%{group: config.group, key: config.key, subkeys: [":groups"]})

      assert Ecto.get_meta(deleted, :state) == :loaded

      assert deleted.value == ConfigDB.to_binary(key: [a: 1])

      updated = ConfigDB.get_by_params(%{group: config.group, key: config.key})

      assert updated.value == deleted.value
    end

    test "full delete if remaining value after subkeys deletion is empty list" do
      config = insert(:config, value: ConfigDB.to_binary(groups: [a: 1, b: 2]))

      {:ok, deleted} =
        ConfigDB.delete(%{group: config.group, key: config.key, subkeys: [":groups"]})

      assert Ecto.get_meta(deleted, :state) == :deleted

      refute ConfigDB.get_by_params(%{group: config.group, key: config.key})
    end
  end

  describe "transform/1" do
    test "string" do
      binary = ConfigDB.transform("value as string")
      assert binary == :erlang.term_to_binary("value as string")
      assert ConfigDB.from_binary(binary) == "value as string"
    end

    test "boolean" do
      binary = ConfigDB.transform(false)
      assert binary == :erlang.term_to_binary(false)
      assert ConfigDB.from_binary(binary) == false
    end

    test "nil" do
      binary = ConfigDB.transform(nil)
      assert binary == :erlang.term_to_binary(nil)
      assert ConfigDB.from_binary(binary) == nil
    end

    test "integer" do
      binary = ConfigDB.transform(150)
      assert binary == :erlang.term_to_binary(150)
      assert ConfigDB.from_binary(binary) == 150
    end

    test "atom" do
      binary = ConfigDB.transform(":atom")
      assert binary == :erlang.term_to_binary(:atom)
      assert ConfigDB.from_binary(binary) == :atom
    end

    test "ssl options" do
      binary = ConfigDB.transform([":tlsv1", ":tlsv1.1", ":tlsv1.2"])
      assert binary == :erlang.term_to_binary([:tlsv1, :"tlsv1.1", :"tlsv1.2"])
      assert ConfigDB.from_binary(binary) == [:tlsv1, :"tlsv1.1", :"tlsv1.2"]
    end

    test "pleroma module" do
      binary = ConfigDB.transform("Pleroma.Bookmark")
      assert binary == :erlang.term_to_binary(Pleroma.Bookmark)
      assert ConfigDB.from_binary(binary) == Pleroma.Bookmark
    end

    test "pleroma string" do
      binary = ConfigDB.transform("Pleroma")
      assert binary == :erlang.term_to_binary("Pleroma")
      assert ConfigDB.from_binary(binary) == "Pleroma"
    end

    test "phoenix module" do
      binary = ConfigDB.transform("Phoenix.Socket.V1.JSONSerializer")
      assert binary == :erlang.term_to_binary(Phoenix.Socket.V1.JSONSerializer)
      assert ConfigDB.from_binary(binary) == Phoenix.Socket.V1.JSONSerializer
    end

    test "tesla module" do
      binary = ConfigDB.transform("Tesla.Adapter.Hackney")
      assert binary == :erlang.term_to_binary(Tesla.Adapter.Hackney)
      assert ConfigDB.from_binary(binary) == Tesla.Adapter.Hackney
    end

    test "ExSyslogger module" do
      binary = ConfigDB.transform("ExSyslogger")
      assert binary == :erlang.term_to_binary(ExSyslogger)
      assert ConfigDB.from_binary(binary) == ExSyslogger
    end

    test "Quack.Logger module" do
      binary = ConfigDB.transform("Quack.Logger")
      assert binary == :erlang.term_to_binary(Quack.Logger)
      assert ConfigDB.from_binary(binary) == Quack.Logger
    end

    test "Swoosh.Adapters modules" do
      binary = ConfigDB.transform("Swoosh.Adapters.SMTP")
      assert binary == :erlang.term_to_binary(Swoosh.Adapters.SMTP)
      assert ConfigDB.from_binary(binary) == Swoosh.Adapters.SMTP
      binary = ConfigDB.transform("Swoosh.Adapters.AmazonSES")
      assert binary == :erlang.term_to_binary(Swoosh.Adapters.AmazonSES)
      assert ConfigDB.from_binary(binary) == Swoosh.Adapters.AmazonSES
    end

    test "sigil" do
      binary = ConfigDB.transform("~r[comp[lL][aA][iI][nN]er]")
      assert binary == :erlang.term_to_binary(~r/comp[lL][aA][iI][nN]er/)
      assert ConfigDB.from_binary(binary) == ~r/comp[lL][aA][iI][nN]er/
    end

    test "link sigil" do
      binary = ConfigDB.transform("~r/https:\/\/example.com/")
      assert binary == :erlang.term_to_binary(~r/https:\/\/example.com/)
      assert ConfigDB.from_binary(binary) == ~r/https:\/\/example.com/
    end

    test "link sigil with um modifiers" do
      binary = ConfigDB.transform("~r/https:\/\/example.com/um")
      assert binary == :erlang.term_to_binary(~r/https:\/\/example.com/um)
      assert ConfigDB.from_binary(binary) == ~r/https:\/\/example.com/um
    end

    test "link sigil with i modifier" do
      binary = ConfigDB.transform("~r/https:\/\/example.com/i")
      assert binary == :erlang.term_to_binary(~r/https:\/\/example.com/i)
      assert ConfigDB.from_binary(binary) == ~r/https:\/\/example.com/i
    end

    test "link sigil with s modifier" do
      binary = ConfigDB.transform("~r/https:\/\/example.com/s")
      assert binary == :erlang.term_to_binary(~r/https:\/\/example.com/s)
      assert ConfigDB.from_binary(binary) == ~r/https:\/\/example.com/s
    end

    test "raise if valid delimiter not found" do
      assert_raise ArgumentError, "valid delimiter for Regex expression not found", fn ->
        ConfigDB.transform("~r/https://[]{}<>\"'()|example.com/s")
      end
    end

    test "2 child tuple" do
      binary = ConfigDB.transform(%{"tuple" => ["v1", ":v2"]})
      assert binary == :erlang.term_to_binary({"v1", :v2})
      assert ConfigDB.from_binary(binary) == {"v1", :v2}
    end

    test "proxy tuple with localhost" do
      binary =
        ConfigDB.transform(%{
          "tuple" => [":proxy_url", %{"tuple" => [":socks5", "localhost", 1234]}]
        })

      assert binary == :erlang.term_to_binary({:proxy_url, {:socks5, :localhost, 1234}})
      assert ConfigDB.from_binary(binary) == {:proxy_url, {:socks5, :localhost, 1234}}
    end

    test "proxy tuple with domain" do
      binary =
        ConfigDB.transform(%{
          "tuple" => [":proxy_url", %{"tuple" => [":socks5", "domain.com", 1234]}]
        })

      assert binary == :erlang.term_to_binary({:proxy_url, {:socks5, 'domain.com', 1234}})
      assert ConfigDB.from_binary(binary) == {:proxy_url, {:socks5, 'domain.com', 1234}}
    end

    test "proxy tuple with ip" do
      binary =
        ConfigDB.transform(%{
          "tuple" => [":proxy_url", %{"tuple" => [":socks5", "127.0.0.1", 1234]}]
        })

      assert binary == :erlang.term_to_binary({:proxy_url, {:socks5, {127, 0, 0, 1}, 1234}})
      assert ConfigDB.from_binary(binary) == {:proxy_url, {:socks5, {127, 0, 0, 1}, 1234}}
    end

    test "tuple with n childs" do
      binary =
        ConfigDB.transform(%{
          "tuple" => [
            "v1",
            ":v2",
            "Pleroma.Bookmark",
            150,
            false,
            "Phoenix.Socket.V1.JSONSerializer"
          ]
        })

      assert binary ==
               :erlang.term_to_binary(
                 {"v1", :v2, Pleroma.Bookmark, 150, false, Phoenix.Socket.V1.JSONSerializer}
               )

      assert ConfigDB.from_binary(binary) ==
               {"v1", :v2, Pleroma.Bookmark, 150, false, Phoenix.Socket.V1.JSONSerializer}
    end

    test "map with string key" do
      binary = ConfigDB.transform(%{"key" => "value"})
      assert binary == :erlang.term_to_binary(%{"key" => "value"})
      assert ConfigDB.from_binary(binary) == %{"key" => "value"}
    end

    test "map with atom key" do
      binary = ConfigDB.transform(%{":key" => "value"})
      assert binary == :erlang.term_to_binary(%{key: "value"})
      assert ConfigDB.from_binary(binary) == %{key: "value"}
    end

    test "list of strings" do
      binary = ConfigDB.transform(["v1", "v2", "v3"])
      assert binary == :erlang.term_to_binary(["v1", "v2", "v3"])
      assert ConfigDB.from_binary(binary) == ["v1", "v2", "v3"]
    end

    test "list of modules" do
      binary = ConfigDB.transform(["Pleroma.Repo", "Pleroma.Activity"])
      assert binary == :erlang.term_to_binary([Pleroma.Repo, Pleroma.Activity])
      assert ConfigDB.from_binary(binary) == [Pleroma.Repo, Pleroma.Activity]
    end

    test "list of atoms" do
      binary = ConfigDB.transform([":v1", ":v2", ":v3"])
      assert binary == :erlang.term_to_binary([:v1, :v2, :v3])
      assert ConfigDB.from_binary(binary) == [:v1, :v2, :v3]
    end

    test "list of mixed values" do
      binary =
        ConfigDB.transform([
          "v1",
          ":v2",
          "Pleroma.Repo",
          "Phoenix.Socket.V1.JSONSerializer",
          15,
          false
        ])

      assert binary ==
               :erlang.term_to_binary([
                 "v1",
                 :v2,
                 Pleroma.Repo,
                 Phoenix.Socket.V1.JSONSerializer,
                 15,
                 false
               ])

      assert ConfigDB.from_binary(binary) == [
               "v1",
               :v2,
               Pleroma.Repo,
               Phoenix.Socket.V1.JSONSerializer,
               15,
               false
             ]
    end

    test "simple keyword" do
      binary = ConfigDB.transform([%{"tuple" => [":key", "value"]}])
      assert binary == :erlang.term_to_binary([{:key, "value"}])
      assert ConfigDB.from_binary(binary) == [{:key, "value"}]
      assert ConfigDB.from_binary(binary) == [key: "value"]
    end

    test "keyword with partial_chain key" do
      binary =
        ConfigDB.transform([%{"tuple" => [":partial_chain", "&:hackney_connect.partial_chain/1"]}])

      assert binary == :erlang.term_to_binary(partial_chain: &:hackney_connect.partial_chain/1)
      assert ConfigDB.from_binary(binary) == [partial_chain: &:hackney_connect.partial_chain/1]
    end

    test "keyword" do
      binary =
        ConfigDB.transform([
          %{"tuple" => [":types", "Pleroma.PostgresTypes"]},
          %{"tuple" => [":telemetry_event", ["Pleroma.Repo.Instrumenter"]]},
          %{"tuple" => [":migration_lock", nil]},
          %{"tuple" => [":key1", 150]},
          %{"tuple" => [":key2", "string"]}
        ])

      assert binary ==
               :erlang.term_to_binary(
                 types: Pleroma.PostgresTypes,
                 telemetry_event: [Pleroma.Repo.Instrumenter],
                 migration_lock: nil,
                 key1: 150,
                 key2: "string"
               )

      assert ConfigDB.from_binary(binary) == [
               types: Pleroma.PostgresTypes,
               telemetry_event: [Pleroma.Repo.Instrumenter],
               migration_lock: nil,
               key1: 150,
               key2: "string"
             ]
    end

    test "complex keyword with nested mixed childs" do
      binary =
        ConfigDB.transform([
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
                    [%{"tuple" => [":follow_redirect", true]}, %{"tuple" => [":pool", ":upload"]}]
                  ]
                }
              ]
            ]
          }
        ])

      assert binary ==
               :erlang.term_to_binary(
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
               )

      assert ConfigDB.from_binary(binary) ==
               [
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
      binary =
        ConfigDB.transform([
          %{"tuple" => [":level", ":warn"]},
          %{"tuple" => [":meta", [":all"]]},
          %{"tuple" => [":path", ""]},
          %{"tuple" => [":val", nil]},
          %{"tuple" => [":webhook_url", "https://hooks.slack.com/services/YOUR-KEY-HERE"]}
        ])

      assert binary ==
               :erlang.term_to_binary(
                 level: :warn,
                 meta: [:all],
                 path: "",
                 val: nil,
                 webhook_url: "https://hooks.slack.com/services/YOUR-KEY-HERE"
               )

      assert ConfigDB.from_binary(binary) == [
               level: :warn,
               meta: [:all],
               path: "",
               val: nil,
               webhook_url: "https://hooks.slack.com/services/YOUR-KEY-HERE"
             ]
    end

    test "complex keyword with sigil" do
      binary =
        ConfigDB.transform([
          %{"tuple" => [":federated_timeline_removal", []]},
          %{"tuple" => [":reject", ["~r/comp[lL][aA][iI][nN]er/"]]},
          %{"tuple" => [":replace", []]}
        ])

      assert binary ==
               :erlang.term_to_binary(
                 federated_timeline_removal: [],
                 reject: [~r/comp[lL][aA][iI][nN]er/],
                 replace: []
               )

      assert ConfigDB.from_binary(binary) ==
               [federated_timeline_removal: [], reject: [~r/comp[lL][aA][iI][nN]er/], replace: []]
    end

    test "complex keyword with tuples with more than 2 values" do
      binary =
        ConfigDB.transform([
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
        ])

      assert binary ==
               :erlang.term_to_binary(
                 http: [
                   key1: [
                     _: [
                       {"/api/v1/streaming", Pleroma.Web.MastodonAPI.WebsocketHandler, []},
                       {"/websocket", Phoenix.Endpoint.CowboyWebSocket,
                        {Phoenix.Transports.WebSocket,
                         {Pleroma.Web.Endpoint, Pleroma.Web.UserSocket, []}}},
                       {:_, Phoenix.Endpoint.Cowboy2Handler, {Pleroma.Web.Endpoint, []}}
                     ]
                   ]
                 ]
               )

      assert ConfigDB.from_binary(binary) == [
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
