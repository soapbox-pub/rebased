# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ConfigTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory
  alias Pleroma.Web.AdminAPI.Config

  test "get_by_key/1" do
    config = insert(:config)
    insert(:config)

    assert config == Config.get_by_params(%{group: config.group, key: config.key})
  end

  test "create/1" do
    {:ok, config} = Config.create(%{group: "pleroma", key: "some_key", value: "some_value"})
    assert config == Config.get_by_params(%{group: "pleroma", key: "some_key"})
  end

  test "update/1" do
    config = insert(:config)
    {:ok, updated} = Config.update(config, %{value: "some_value"})
    loaded = Config.get_by_params(%{group: config.group, key: config.key})
    assert loaded == updated
  end

  describe "update_or_create/1" do
    test "common" do
      config = insert(:config)
      key2 = "another_key"

      params = [
        %{group: "pleroma", key: key2, value: "another_value"},
        %{group: config.group, key: config.key, value: "new_value"}
      ]

      assert Repo.all(Config) |> length() == 1

      Enum.each(params, &Config.update_or_create(&1))

      assert Repo.all(Config) |> length() == 2

      config1 = Config.get_by_params(%{group: config.group, key: config.key})
      config2 = Config.get_by_params(%{group: "pleroma", key: key2})

      assert config1.value == Config.transform("new_value")
      assert config2.value == Config.transform("another_value")
    end

    test "partial update" do
      config = insert(:config, value: Config.to_binary(key1: "val1", key2: :val2))

      {:ok, _config} =
        Config.update_or_create(%{
          group: config.group,
          key: config.key,
          value: [key1: :val1, key3: :val3]
        })

      updated = Config.get_by_params(%{group: config.group, key: config.key})

      value = Config.from_binary(updated.value)
      assert length(value) == 3
      assert value[:key1] == :val1
      assert value[:key2] == :val2
      assert value[:key3] == :val3
    end

    test "only full update for some keys" do
      config1 = insert(:config, key: ":ecto_repos", value: Config.to_binary(repo: Pleroma.Repo))
      config2 = insert(:config, group: ":cors_plug", key: ":max_age", value: Config.to_binary(18))

      {:ok, _config} =
        Config.update_or_create(%{
          group: config1.group,
          key: config1.key,
          value: [another_repo: [Pleroma.Repo]]
        })

      {:ok, _config} =
        Config.update_or_create(%{
          group: config2.group,
          key: config2.key,
          value: 777
        })

      updated1 = Config.get_by_params(%{group: config1.group, key: config1.key})
      updated2 = Config.get_by_params(%{group: config2.group, key: config2.key})

      assert Config.from_binary(updated1.value) == [another_repo: [Pleroma.Repo]]
      assert Config.from_binary(updated2.value) == 777
    end

    test "full update if value is not keyword" do
      config =
        insert(:config,
          group: ":tesla",
          key: ":adapter",
          value: Config.to_binary(Tesla.Adapter.Hackney)
        )

      {:ok, _config} =
        Config.update_or_create(%{
          group: config.group,
          key: config.key,
          value: Tesla.Adapter.Httpc
        })

      updated = Config.get_by_params(%{group: config.group, key: config.key})

      assert Config.from_binary(updated.value) == Tesla.Adapter.Httpc
    end
  end

  test "delete/1" do
    config = insert(:config)
    {:ok, _} = Config.delete(%{key: config.key, group: config.group})
    refute Config.get_by_params(%{key: config.key, group: config.group})
  end

  describe "transform/1" do
    test "string" do
      binary = Config.transform("value as string")
      assert binary == :erlang.term_to_binary("value as string")
      assert Config.from_binary(binary) == "value as string"
    end

    test "boolean" do
      binary = Config.transform(false)
      assert binary == :erlang.term_to_binary(false)
      assert Config.from_binary(binary) == false
    end

    test "nil" do
      binary = Config.transform(nil)
      assert binary == :erlang.term_to_binary(nil)
      assert Config.from_binary(binary) == nil
    end

    test "integer" do
      binary = Config.transform(150)
      assert binary == :erlang.term_to_binary(150)
      assert Config.from_binary(binary) == 150
    end

    test "atom" do
      binary = Config.transform(":atom")
      assert binary == :erlang.term_to_binary(:atom)
      assert Config.from_binary(binary) == :atom
    end

    test "pleroma module" do
      binary = Config.transform("Pleroma.Bookmark")
      assert binary == :erlang.term_to_binary(Pleroma.Bookmark)
      assert Config.from_binary(binary) == Pleroma.Bookmark
    end

    test "pleroma string" do
      binary = Config.transform("Pleroma")
      assert binary == :erlang.term_to_binary("Pleroma")
      assert Config.from_binary(binary) == "Pleroma"
    end

    test "phoenix module" do
      binary = Config.transform("Phoenix.Socket.V1.JSONSerializer")
      assert binary == :erlang.term_to_binary(Phoenix.Socket.V1.JSONSerializer)
      assert Config.from_binary(binary) == Phoenix.Socket.V1.JSONSerializer
    end

    test "tesla module" do
      binary = Config.transform("Tesla.Adapter.Hackney")
      assert binary == :erlang.term_to_binary(Tesla.Adapter.Hackney)
      assert Config.from_binary(binary) == Tesla.Adapter.Hackney
    end

    test "sigil" do
      binary = Config.transform("~r[comp[lL][aA][iI][nN]er]")
      assert binary == :erlang.term_to_binary(~r/comp[lL][aA][iI][nN]er/)
      assert Config.from_binary(binary) == ~r/comp[lL][aA][iI][nN]er/
    end

    test "link sigil" do
      binary = Config.transform("~r/https:\/\/example.com/")
      assert binary == :erlang.term_to_binary(~r/https:\/\/example.com/)
      assert Config.from_binary(binary) == ~r/https:\/\/example.com/
    end

    test "link sigil with um modifiers" do
      binary = Config.transform("~r/https:\/\/example.com/um")
      assert binary == :erlang.term_to_binary(~r/https:\/\/example.com/um)
      assert Config.from_binary(binary) == ~r/https:\/\/example.com/um
    end

    test "link sigil with i modifier" do
      binary = Config.transform("~r/https:\/\/example.com/i")
      assert binary == :erlang.term_to_binary(~r/https:\/\/example.com/i)
      assert Config.from_binary(binary) == ~r/https:\/\/example.com/i
    end

    test "link sigil with s modifier" do
      binary = Config.transform("~r/https:\/\/example.com/s")
      assert binary == :erlang.term_to_binary(~r/https:\/\/example.com/s)
      assert Config.from_binary(binary) == ~r/https:\/\/example.com/s
    end

    test "raise if valid delimiter not found" do
      assert_raise ArgumentError, "valid delimiter for Regex expression not found", fn ->
        Config.transform("~r/https://[]{}<>\"'()|example.com/s")
      end
    end

    test "2 child tuple" do
      binary = Config.transform(%{"tuple" => ["v1", ":v2"]})
      assert binary == :erlang.term_to_binary({"v1", :v2})
      assert Config.from_binary(binary) == {"v1", :v2}
    end

    test "tuple with n childs" do
      binary =
        Config.transform(%{
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

      assert Config.from_binary(binary) ==
               {"v1", :v2, Pleroma.Bookmark, 150, false, Phoenix.Socket.V1.JSONSerializer}
    end

    test "tuple with dispatch key" do
      binary = Config.transform(%{"tuple" => [":dispatch", ["{:_,
       [
         {\"/api/v1/streaming\", Pleroma.Web.MastodonAPI.WebsocketHandler, []},
         {\"/websocket\", Phoenix.Endpoint.CowboyWebSocket,
          {Phoenix.Transports.WebSocket,
           {Pleroma.Web.Endpoint, Pleroma.Web.UserSocket, [path: \"/websocket\"]}}},
         {:_, Phoenix.Endpoint.Cowboy2Handler, {Pleroma.Web.Endpoint, []}}
       ]}"]]})

      assert binary ==
               :erlang.term_to_binary(
                 {:dispatch,
                  [
                    {:_,
                     [
                       {"/api/v1/streaming", Pleroma.Web.MastodonAPI.WebsocketHandler, []},
                       {"/websocket", Phoenix.Endpoint.CowboyWebSocket,
                        {Phoenix.Transports.WebSocket,
                         {Pleroma.Web.Endpoint, Pleroma.Web.UserSocket, [path: "/websocket"]}}},
                       {:_, Phoenix.Endpoint.Cowboy2Handler, {Pleroma.Web.Endpoint, []}}
                     ]}
                  ]}
               )

      assert Config.from_binary(binary) ==
               {:dispatch,
                [
                  {:_,
                   [
                     {"/api/v1/streaming", Pleroma.Web.MastodonAPI.WebsocketHandler, []},
                     {"/websocket", Phoenix.Endpoint.CowboyWebSocket,
                      {Phoenix.Transports.WebSocket,
                       {Pleroma.Web.Endpoint, Pleroma.Web.UserSocket, [path: "/websocket"]}}},
                     {:_, Phoenix.Endpoint.Cowboy2Handler, {Pleroma.Web.Endpoint, []}}
                   ]}
                ]}
    end

    test "map with string key" do
      binary = Config.transform(%{"key" => "value"})
      assert binary == :erlang.term_to_binary(%{"key" => "value"})
      assert Config.from_binary(binary) == %{"key" => "value"}
    end

    test "map with atom key" do
      binary = Config.transform(%{":key" => "value"})
      assert binary == :erlang.term_to_binary(%{key: "value"})
      assert Config.from_binary(binary) == %{key: "value"}
    end

    test "list of strings" do
      binary = Config.transform(["v1", "v2", "v3"])
      assert binary == :erlang.term_to_binary(["v1", "v2", "v3"])
      assert Config.from_binary(binary) == ["v1", "v2", "v3"]
    end

    test "list of modules" do
      binary = Config.transform(["Pleroma.Repo", "Pleroma.Activity"])
      assert binary == :erlang.term_to_binary([Pleroma.Repo, Pleroma.Activity])
      assert Config.from_binary(binary) == [Pleroma.Repo, Pleroma.Activity]
    end

    test "list of atoms" do
      binary = Config.transform([":v1", ":v2", ":v3"])
      assert binary == :erlang.term_to_binary([:v1, :v2, :v3])
      assert Config.from_binary(binary) == [:v1, :v2, :v3]
    end

    test "list of mixed values" do
      binary =
        Config.transform([
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

      assert Config.from_binary(binary) == [
               "v1",
               :v2,
               Pleroma.Repo,
               Phoenix.Socket.V1.JSONSerializer,
               15,
               false
             ]
    end

    test "simple keyword" do
      binary = Config.transform([%{"tuple" => [":key", "value"]}])
      assert binary == :erlang.term_to_binary([{:key, "value"}])
      assert Config.from_binary(binary) == [{:key, "value"}]
      assert Config.from_binary(binary) == [key: "value"]
    end

    test "keyword with partial_chain key" do
      binary =
        Config.transform([%{"tuple" => [":partial_chain", "&:hackney_connect.partial_chain/1"]}])

      assert binary == :erlang.term_to_binary(partial_chain: &:hackney_connect.partial_chain/1)
      assert Config.from_binary(binary) == [partial_chain: &:hackney_connect.partial_chain/1]
    end

    test "keyword" do
      binary =
        Config.transform([
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

      assert Config.from_binary(binary) == [
               types: Pleroma.PostgresTypes,
               telemetry_event: [Pleroma.Repo.Instrumenter],
               migration_lock: nil,
               key1: 150,
               key2: "string"
             ]
    end

    test "complex keyword with nested mixed childs" do
      binary =
        Config.transform([
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

      assert Config.from_binary(binary) ==
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
        Config.transform([
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

      assert Config.from_binary(binary) == [
               level: :warn,
               meta: [:all],
               path: "",
               val: nil,
               webhook_url: "https://hooks.slack.com/services/YOUR-KEY-HERE"
             ]
    end

    test "complex keyword with sigil" do
      binary =
        Config.transform([
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

      assert Config.from_binary(binary) ==
               [federated_timeline_removal: [], reject: [~r/comp[lL][aA][iI][nN]er/], replace: []]
    end

    test "complex keyword with tuples with more than 2 values" do
      binary =
        Config.transform([
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

      assert Config.from_binary(binary) == [
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
