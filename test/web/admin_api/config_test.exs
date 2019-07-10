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

  test "update_or_create/1" do
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

    test "list of modules" do
      binary = Config.transform(["Pleroma.Repo", "Pleroma.Activity"])
      assert binary == :erlang.term_to_binary([Pleroma.Repo, Pleroma.Activity])
      assert Config.from_binary(binary) == [Pleroma.Repo, Pleroma.Activity]
    end

    test "list of strings" do
      binary = Config.transform(["string1", "string2"])
      assert binary == :erlang.term_to_binary(["string1", "string2"])
      assert Config.from_binary(binary) == ["string1", "string2"]
    end

    test "map" do
      binary =
        Config.transform(%{
          "types" => "Pleroma.PostgresTypes",
          "telemetry_event" => ["Pleroma.Repo.Instrumenter"],
          "migration_lock" => ""
        })

      assert binary ==
               :erlang.term_to_binary(
                 telemetry_event: [Pleroma.Repo.Instrumenter],
                 types: Pleroma.PostgresTypes
               )

      assert Config.from_binary(binary) == [
               telemetry_event: [Pleroma.Repo.Instrumenter],
               types: Pleroma.PostgresTypes
             ]
    end

    test "complex map with nested integers, lists and atoms" do
      binary =
        Config.transform(%{
          "uploader" => "Pleroma.Uploaders.Local",
          "filters" => ["Pleroma.Upload.Filter.Dedupe"],
          "link_name" => ":true",
          "proxy_remote" => ":false",
          "proxy_opts" => %{
            "redirect_on_failure" => ":false",
            "max_body_length" => "i:1048576",
            "http" => %{
              "follow_redirect" => ":true",
              "pool" => ":upload"
            }
          }
        })

      assert binary ==
               :erlang.term_to_binary(
                 filters: [Pleroma.Upload.Filter.Dedupe],
                 link_name: true,
                 proxy_opts: [
                   http: [
                     follow_redirect: true,
                     pool: :upload
                   ],
                   max_body_length: 1_048_576,
                   redirect_on_failure: false
                 ],
                 proxy_remote: false,
                 uploader: Pleroma.Uploaders.Local
               )

      assert Config.from_binary(binary) ==
               [
                 filters: [Pleroma.Upload.Filter.Dedupe],
                 link_name: true,
                 proxy_opts: [
                   http: [
                     follow_redirect: true,
                     pool: :upload
                   ],
                   max_body_length: 1_048_576,
                   redirect_on_failure: false
                 ],
                 proxy_remote: false,
                 uploader: Pleroma.Uploaders.Local
               ]
    end

    test "keyword" do
      binary =
        Config.transform(%{
          "level" => ":warn",
          "meta" => [":all"],
          "webhook_url" => "https://hooks.slack.com/services/YOUR-KEY-HERE"
        })

      assert binary ==
               :erlang.term_to_binary(
                 level: :warn,
                 meta: [:all],
                 webhook_url: "https://hooks.slack.com/services/YOUR-KEY-HERE"
               )

      assert Config.from_binary(binary) == [
               level: :warn,
               meta: [:all],
               webhook_url: "https://hooks.slack.com/services/YOUR-KEY-HERE"
             ]
    end

    test "complex map with sigil" do
      binary =
        Config.transform(%{
          federated_timeline_removal: [],
          reject: [~r/comp[lL][aA][iI][nN]er/],
          replace: []
        })

      assert binary ==
               :erlang.term_to_binary(
                 federated_timeline_removal: [],
                 reject: [~r/comp[lL][aA][iI][nN]er/],
                 replace: []
               )

      assert Config.from_binary(binary) ==
               [federated_timeline_removal: [], reject: [~r/comp[lL][aA][iI][nN]er/], replace: []]
    end

    test "complex map with tuples with more than 2 values" do
      binary =
        Config.transform(%{
          "http" => %{
            "dispatch" => [
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
                            %{"tuple" => ["Pleroma.Web.Endpoint", "Pleroma.Web.UserSocket", []]}
                          ]
                        }
                      ]
                    },
                    %{
                      "tuple" => [
                        ":_",
                        "Phoenix.Endpoint.Cowboy2Handler",
                        %{
                          "tuple" => ["Pleroma.Web.Endpoint", []]
                        }
                      ]
                    }
                  ]
                ]
              }
            ]
          }
        })

      assert binary ==
               :erlang.term_to_binary(
                 http: [
                   dispatch: [
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
                 dispatch: [
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
