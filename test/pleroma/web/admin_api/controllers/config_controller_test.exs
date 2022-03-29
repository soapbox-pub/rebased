# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ConfigControllerTest do
  use Pleroma.Web.ConnCase

  import ExUnit.CaptureLog
  import Pleroma.Factory

  alias Pleroma.ConfigDB

  setup do
    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  describe "GET /api/pleroma/admin/config" do
    setup do: clear_config(:configurable_from_database, true)

    test "when configuration from database is off", %{conn: conn} do
      clear_config(:configurable_from_database, false)
      conn = get(conn, "/api/pleroma/admin/config")

      assert json_response_and_validate_schema(conn, 400) ==
               %{
                 "error" => "You must enable configurable_from_database in your config file."
               }
    end

    test "with settings only in db", %{conn: conn} do
      config1 = insert(:config)
      config2 = insert(:config)

      conn = get(conn, "/api/pleroma/admin/config?only_db=true")

      %{
        "configs" => [
          %{
            "group" => ":pleroma",
            "key" => key1,
            "value" => _
          },
          %{
            "group" => ":pleroma",
            "key" => key2,
            "value" => _
          }
        ]
      } = json_response_and_validate_schema(conn, 200)

      assert key1 == inspect(config1.key)
      assert key2 == inspect(config2.key)
    end

    test "db is added to settings that are in db", %{conn: conn} do
      _config = insert(:config, key: ":instance", value: [name: "Some name"])

      %{"configs" => configs} =
        conn
        |> get("/api/pleroma/admin/config")
        |> json_response_and_validate_schema(200)

      [instance_config] =
        Enum.filter(configs, fn %{"group" => group, "key" => key} ->
          group == ":pleroma" and key == ":instance"
        end)

      assert instance_config["db"] == [":name"]
    end

    test "merged default setting with db settings", %{conn: conn} do
      config1 = insert(:config)
      config2 = insert(:config)

      config3 =
        insert(:config,
          value: [k1: :v1, k2: :v2]
        )

      %{"configs" => configs} =
        conn
        |> get("/api/pleroma/admin/config")
        |> json_response_and_validate_schema(200)

      assert length(configs) > 3

      saved_configs = [config1, config2, config3]
      keys = Enum.map(saved_configs, &inspect(&1.key))

      received_configs =
        Enum.filter(configs, fn %{"group" => group, "key" => key} ->
          group == ":pleroma" and key in keys
        end)

      assert length(received_configs) == 3

      db_keys =
        config3.value
        |> Keyword.keys()
        |> ConfigDB.to_json_types()

      keys = Enum.map(saved_configs -- [config3], &inspect(&1.key))

      values = Enum.map(saved_configs, &ConfigDB.to_json_types(&1.value))

      mapset_keys = MapSet.new(keys ++ db_keys)

      Enum.each(received_configs, fn %{"value" => value, "db" => db} ->
        db = MapSet.new(db)
        assert MapSet.subset?(db, mapset_keys)

        assert value in values
      end)
    end

    test "subkeys with full update right merge", %{conn: conn} do
      insert(:config,
        key: ":emoji",
        value: [groups: [a: 1, b: 2], key: [a: 1]]
      )

      insert(:config,
        key: ":assets",
        value: [mascots: [a: 1, b: 2], key: [a: 1]]
      )

      %{"configs" => configs} =
        conn
        |> get("/api/pleroma/admin/config")
        |> json_response_and_validate_schema(200)

      vals =
        Enum.filter(configs, fn %{"group" => group, "key" => key} ->
          group == ":pleroma" and key in [":emoji", ":assets"]
        end)

      emoji = Enum.find(vals, fn %{"key" => key} -> key == ":emoji" end)
      assets = Enum.find(vals, fn %{"key" => key} -> key == ":assets" end)

      emoji_val = ConfigDB.to_elixir_types(emoji["value"])
      assets_val = ConfigDB.to_elixir_types(assets["value"])

      assert emoji_val[:groups] == [a: 1, b: 2]
      assert assets_val[:mascots] == [a: 1, b: 2]
    end

    test "with valid `admin_token` query parameter, skips OAuth scopes check" do
      clear_config([:admin_token], "password123")

      build_conn()
      |> get("/api/pleroma/admin/config?admin_token=password123")
      |> json_response_and_validate_schema(200)
    end
  end

  test "POST /api/pleroma/admin/config with configdb disabled", %{conn: conn} do
    clear_config(:configurable_from_database, false)

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/pleroma/admin/config", %{"configs" => []})

    assert json_response_and_validate_schema(conn, 400) ==
             %{"error" => "You must enable configurable_from_database in your config file."}
  end

  describe "POST /api/pleroma/admin/config" do
    setup do
      http = Application.get_env(:pleroma, :http)

      on_exit(fn ->
        Application.delete_env(:pleroma, :key1)
        Application.delete_env(:pleroma, :key2)
        Application.delete_env(:pleroma, :key3)
        Application.delete_env(:pleroma, :key4)
        Application.delete_env(:pleroma, :keyaa1)
        Application.delete_env(:pleroma, :keyaa2)
        Application.delete_env(:pleroma, Pleroma.Web.Endpoint.NotReal)
        Application.delete_env(:pleroma, Pleroma.Captcha.NotReal)
        Application.put_env(:pleroma, :http, http)
        Application.put_env(:tesla, :adapter, Tesla.Mock)
        Restarter.Pleroma.refresh()
      end)
    end

    setup do: clear_config(:configurable_from_database, true)

    @tag capture_log: true
    test "create new config setting in db", %{conn: conn} do
      ueberauth = Application.get_env(:ueberauth, Ueberauth)
      on_exit(fn -> Application.put_env(:ueberauth, Ueberauth, ueberauth) end)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{group: ":pleroma", key: ":key1", value: "value1"},
            %{
              group: ":ueberauth",
              key: "Ueberauth",
              value: [%{"tuple" => [":consumer_secret", "aaaa"]}]
            },
            %{
              group: ":pleroma",
              key: ":key2",
              value: %{
                ":nested_1" => "nested_value1",
                ":nested_2" => [
                  %{":nested_22" => "nested_value222"},
                  %{":nested_33" => %{":nested_44" => "nested_444"}}
                ]
              }
            },
            %{
              group: ":pleroma",
              key: ":key3",
              value: [
                %{"nested_3" => ":nested_3", "nested_33" => "nested_33"},
                %{"nested_4" => true}
              ]
            },
            %{
              group: ":pleroma",
              key: ":key4",
              value: %{":nested_5" => ":upload", "endpoint" => "https://example.com"}
            },
            %{
              group: ":idna",
              key: ":key5",
              value: %{"tuple" => ["string", "Pleroma.Captcha.NotReal", []]}
            }
          ]
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":key1",
                   "value" => "value1",
                   "db" => [":key1"]
                 },
                 %{
                   "group" => ":ueberauth",
                   "key" => "Ueberauth",
                   "value" => [%{"tuple" => [":consumer_secret", "aaaa"]}],
                   "db" => [":consumer_secret"]
                 },
                 %{
                   "group" => ":pleroma",
                   "key" => ":key2",
                   "value" => %{
                     ":nested_1" => "nested_value1",
                     ":nested_2" => [
                       %{":nested_22" => "nested_value222"},
                       %{":nested_33" => %{":nested_44" => "nested_444"}}
                     ]
                   },
                   "db" => [":key2"]
                 },
                 %{
                   "group" => ":pleroma",
                   "key" => ":key3",
                   "value" => [
                     %{"nested_3" => ":nested_3", "nested_33" => "nested_33"},
                     %{"nested_4" => true}
                   ],
                   "db" => [":key3"]
                 },
                 %{
                   "group" => ":pleroma",
                   "key" => ":key4",
                   "value" => %{"endpoint" => "https://example.com", ":nested_5" => ":upload"},
                   "db" => [":key4"]
                 },
                 %{
                   "group" => ":idna",
                   "key" => ":key5",
                   "value" => %{"tuple" => ["string", "Pleroma.Captcha.NotReal", []]},
                   "db" => [":key5"]
                 }
               ],
               "need_reboot" => false
             }

      assert Application.get_env(:pleroma, :key1) == "value1"

      assert Application.get_env(:pleroma, :key2) == %{
               nested_1: "nested_value1",
               nested_2: [
                 %{nested_22: "nested_value222"},
                 %{nested_33: %{nested_44: "nested_444"}}
               ]
             }

      assert Application.get_env(:pleroma, :key3) == [
               %{"nested_3" => :nested_3, "nested_33" => "nested_33"},
               %{"nested_4" => true}
             ]

      assert Application.get_env(:pleroma, :key4) == %{
               "endpoint" => "https://example.com",
               nested_5: :upload
             }

      assert Application.get_env(:idna, :key5) == {"string", Pleroma.Captcha.NotReal, []}
    end

    test "save configs setting without explicit key", %{conn: conn} do
      level = Application.get_env(:quack, :level)
      meta = Application.get_env(:quack, :meta)
      webhook_url = Application.get_env(:quack, :webhook_url)

      on_exit(fn ->
        Application.put_env(:quack, :level, level)
        Application.put_env(:quack, :meta, meta)
        Application.put_env(:quack, :webhook_url, webhook_url)
      end)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{
              group: ":quack",
              key: ":level",
              value: ":info"
            },
            %{
              group: ":quack",
              key: ":meta",
              value: [":none"]
            },
            %{
              group: ":quack",
              key: ":webhook_url",
              value: "https://hooks.slack.com/services/KEY"
            }
          ]
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":quack",
                   "key" => ":level",
                   "value" => ":info",
                   "db" => [":level"]
                 },
                 %{
                   "group" => ":quack",
                   "key" => ":meta",
                   "value" => [":none"],
                   "db" => [":meta"]
                 },
                 %{
                   "group" => ":quack",
                   "key" => ":webhook_url",
                   "value" => "https://hooks.slack.com/services/KEY",
                   "db" => [":webhook_url"]
                 }
               ],
               "need_reboot" => false
             }

      assert Application.get_env(:quack, :level) == :info
      assert Application.get_env(:quack, :meta) == [:none]
      assert Application.get_env(:quack, :webhook_url) == "https://hooks.slack.com/services/KEY"
    end

    test "saving config with partial update", %{conn: conn} do
      insert(:config, key: ":key1", value: :erlang.term_to_binary(key1: 1, key2: 2))

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{group: ":pleroma", key: ":key1", value: [%{"tuple" => [":key3", 3]}]}
          ]
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":key1",
                   "value" => [
                     %{"tuple" => [":key1", 1]},
                     %{"tuple" => [":key2", 2]},
                     %{"tuple" => [":key3", 3]}
                   ],
                   "db" => [":key1", ":key2", ":key3"]
                 }
               ],
               "need_reboot" => false
             }
    end

    test "saving config which need pleroma reboot", %{conn: conn} do
      clear_config([:shout, :enabled], true)

      assert conn
             |> put_req_header("content-type", "application/json")
             |> post(
               "/api/pleroma/admin/config",
               %{
                 configs: [
                   %{group: ":pleroma", key: ":shout", value: [%{"tuple" => [":enabled", true]}]}
                 ]
               }
             )
             |> json_response_and_validate_schema(200) == %{
               "configs" => [
                 %{
                   "db" => [":enabled"],
                   "group" => ":pleroma",
                   "key" => ":shout",
                   "value" => [%{"tuple" => [":enabled", true]}]
                 }
               ],
               "need_reboot" => true
             }

      configs =
        conn
        |> get("/api/pleroma/admin/config")
        |> json_response_and_validate_schema(200)

      assert configs["need_reboot"]

      capture_log(fn ->
        assert conn |> get("/api/pleroma/admin/restart") |> json_response(200) ==
                 %{}
      end) =~ "pleroma restarted"

      configs =
        conn
        |> get("/api/pleroma/admin/config")
        |> json_response_and_validate_schema(200)

      assert configs["need_reboot"] == false
    end

    test "update setting which need reboot, don't change reboot flag until reboot", %{conn: conn} do
      clear_config([:shout, :enabled], true)

      assert conn
             |> put_req_header("content-type", "application/json")
             |> post(
               "/api/pleroma/admin/config",
               %{
                 configs: [
                   %{group: ":pleroma", key: ":shout", value: [%{"tuple" => [":enabled", true]}]}
                 ]
               }
             )
             |> json_response_and_validate_schema(200) == %{
               "configs" => [
                 %{
                   "db" => [":enabled"],
                   "group" => ":pleroma",
                   "key" => ":shout",
                   "value" => [%{"tuple" => [":enabled", true]}]
                 }
               ],
               "need_reboot" => true
             }

      assert conn
             |> put_req_header("content-type", "application/json")
             |> post("/api/pleroma/admin/config", %{
               configs: [
                 %{group: ":pleroma", key: ":key1", value: [%{"tuple" => [":key3", 3]}]}
               ]
             })
             |> json_response_and_validate_schema(200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":key1",
                   "value" => [
                     %{"tuple" => [":key3", 3]}
                   ],
                   "db" => [":key3"]
                 }
               ],
               "need_reboot" => true
             }

      capture_log(fn ->
        assert conn |> get("/api/pleroma/admin/restart") |> json_response(200) ==
                 %{}
      end) =~ "pleroma restarted"

      configs =
        conn
        |> get("/api/pleroma/admin/config")
        |> json_response_and_validate_schema(200)

      assert configs["need_reboot"] == false
    end

    test "saving config with nested merge", %{conn: conn} do
      insert(:config, key: :key1, value: [key1: 1, key2: [k1: 1, k2: 2]])

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{
              group: ":pleroma",
              key: ":key1",
              value: [
                %{"tuple" => [":key3", 3]},
                %{
                  "tuple" => [
                    ":key2",
                    [
                      %{"tuple" => [":k2", 1]},
                      %{"tuple" => [":k3", 3]}
                    ]
                  ]
                }
              ]
            }
          ]
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":key1",
                   "value" => [
                     %{"tuple" => [":key1", 1]},
                     %{"tuple" => [":key3", 3]},
                     %{
                       "tuple" => [
                         ":key2",
                         [
                           %{"tuple" => [":k1", 1]},
                           %{"tuple" => [":k2", 1]},
                           %{"tuple" => [":k3", 3]}
                         ]
                       ]
                     }
                   ],
                   "db" => [":key1", ":key3", ":key2"]
                 }
               ],
               "need_reboot" => false
             }
    end

    test "saving special atoms", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          "configs" => [
            %{
              "group" => ":pleroma",
              "key" => ":key1",
              "value" => [
                %{
                  "tuple" => [
                    ":ssl_options",
                    [%{"tuple" => [":versions", [":tlsv1", ":tlsv1.1", ":tlsv1.2"]]}]
                  ]
                }
              ]
            }
          ]
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":key1",
                   "value" => [
                     %{
                       "tuple" => [
                         ":ssl_options",
                         [%{"tuple" => [":versions", [":tlsv1", ":tlsv1.1", ":tlsv1.2"]]}]
                       ]
                     }
                   ],
                   "db" => [":ssl_options"]
                 }
               ],
               "need_reboot" => false
             }

      assert Application.get_env(:pleroma, :key1) == [
               ssl_options: [versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"]]
             ]
    end

    test "saving full setting if value is in full_key_update list", %{conn: conn} do
      backends = Application.get_env(:logger, :backends)
      on_exit(fn -> Application.put_env(:logger, :backends, backends) end)

      insert(:config,
        group: :logger,
        key: :backends,
        value: []
      )

      Pleroma.Config.TransferTask.load_and_update_env([], false)

      assert Application.get_env(:logger, :backends) == []

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{
              group: ":logger",
              key: ":backends",
              value: [":console"]
            }
          ]
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":logger",
                   "key" => ":backends",
                   "value" => [
                     ":console"
                   ],
                   "db" => [":backends"]
                 }
               ],
               "need_reboot" => false
             }

      assert Application.get_env(:logger, :backends) == [
               :console
             ]
    end

    test "saving full setting if value is not keyword", %{conn: conn} do
      insert(:config,
        group: :tesla,
        key: :adapter,
        value: Tesla.Adapter.Hackey
      )

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{group: ":tesla", key: ":adapter", value: "Tesla.Adapter.Httpc"}
          ]
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":tesla",
                   "key" => ":adapter",
                   "value" => "Tesla.Adapter.Httpc",
                   "db" => [":adapter"]
                 }
               ],
               "need_reboot" => false
             }
    end

    test "update config setting & delete with fallback to default value", %{
      conn: conn,
      admin: admin,
      token: token
    } do
      ueberauth = Application.get_env(:ueberauth, Ueberauth)
      insert(:config, key: :keyaa1)
      insert(:config, key: :keyaa2)

      config3 =
        insert(:config,
          group: :ueberauth,
          key: Ueberauth
        )

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{group: ":pleroma", key: ":keyaa1", value: "another_value"},
            %{group: ":pleroma", key: ":keyaa2", value: "another_value"}
          ]
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":keyaa1",
                   "value" => "another_value",
                   "db" => [":keyaa1"]
                 },
                 %{
                   "group" => ":pleroma",
                   "key" => ":keyaa2",
                   "value" => "another_value",
                   "db" => [":keyaa2"]
                 }
               ],
               "need_reboot" => false
             }

      assert Application.get_env(:pleroma, :keyaa1) == "another_value"
      assert Application.get_env(:pleroma, :keyaa2) == "another_value"
      assert Application.get_env(:ueberauth, Ueberauth) == config3.value

      conn =
        build_conn()
        |> assign(:user, admin)
        |> assign(:token, token)
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{group: ":pleroma", key: ":keyaa2", delete: true},
            %{
              group: ":ueberauth",
              key: "Ueberauth",
              delete: true
            }
          ]
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "configs" => [],
               "need_reboot" => false
             }

      assert Application.get_env(:ueberauth, Ueberauth) == ueberauth
      refute Keyword.has_key?(Application.get_all_env(:pleroma), :keyaa2)
    end

    test "common config example", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{
              "group" => ":pleroma",
              "key" => "Pleroma.Captcha.NotReal",
              "value" => [
                %{"tuple" => [":enabled", false]},
                %{"tuple" => [":method", "Pleroma.Captcha.Kocaptcha"]},
                %{"tuple" => [":seconds_valid", 60]},
                %{"tuple" => [":path", ""]},
                %{"tuple" => [":key1", nil]},
                %{"tuple" => [":partial_chain", "&:hackney_connect.partial_chain/1"]},
                %{"tuple" => [":regex1", "~r/https:\/\/example.com/"]},
                %{"tuple" => [":regex2", "~r/https:\/\/example.com/u"]},
                %{"tuple" => [":regex3", "~r/https:\/\/example.com/i"]},
                %{"tuple" => [":regex4", "~r/https:\/\/example.com/s"]},
                %{"tuple" => [":name", "Pleroma"]}
              ]
            }
          ]
        })

      assert Config.get([Pleroma.Captcha.NotReal, :name]) == "Pleroma"

      assert json_response_and_validate_schema(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => "Pleroma.Captcha.NotReal",
                   "value" => [
                     %{"tuple" => [":enabled", false]},
                     %{"tuple" => [":method", "Pleroma.Captcha.Kocaptcha"]},
                     %{"tuple" => [":seconds_valid", 60]},
                     %{"tuple" => [":path", ""]},
                     %{"tuple" => [":key1", nil]},
                     %{"tuple" => [":partial_chain", "&:hackney_connect.partial_chain/1"]},
                     %{"tuple" => [":regex1", "~r/https:\\/\\/example.com/"]},
                     %{"tuple" => [":regex2", "~r/https:\\/\\/example.com/u"]},
                     %{"tuple" => [":regex3", "~r/https:\\/\\/example.com/i"]},
                     %{"tuple" => [":regex4", "~r/https:\\/\\/example.com/s"]},
                     %{"tuple" => [":name", "Pleroma"]}
                   ],
                   "db" => [
                     ":enabled",
                     ":method",
                     ":seconds_valid",
                     ":path",
                     ":key1",
                     ":partial_chain",
                     ":regex1",
                     ":regex2",
                     ":regex3",
                     ":regex4",
                     ":name"
                   ]
                 }
               ],
               "need_reboot" => false
             }
    end

    test "tuples with more than two values", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{
              "group" => ":pleroma",
              "key" => "Pleroma.Web.Endpoint.NotReal",
              "value" => [
                %{
                  "tuple" => [
                    ":http",
                    [
                      %{
                        "tuple" => [
                          ":key2",
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
              ]
            }
          ]
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => "Pleroma.Web.Endpoint.NotReal",
                   "value" => [
                     %{
                       "tuple" => [
                         ":http",
                         [
                           %{
                             "tuple" => [
                               ":key2",
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
                   ],
                   "db" => [":http"]
                 }
               ],
               "need_reboot" => false
             }
    end

    test "settings with nesting map", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{
              "group" => ":pleroma",
              "key" => ":key1",
              "value" => [
                %{"tuple" => [":key2", "some_val"]},
                %{
                  "tuple" => [
                    ":key3",
                    %{
                      ":max_options" => 20,
                      ":max_option_chars" => 200,
                      ":min_expiration" => 0,
                      ":max_expiration" => 31_536_000,
                      "nested" => %{
                        ":max_options" => 20,
                        ":max_option_chars" => 200,
                        ":min_expiration" => 0,
                        ":max_expiration" => 31_536_000
                      }
                    }
                  ]
                }
              ]
            }
          ]
        })

      assert json_response_and_validate_schema(conn, 200) ==
               %{
                 "configs" => [
                   %{
                     "group" => ":pleroma",
                     "key" => ":key1",
                     "value" => [
                       %{"tuple" => [":key2", "some_val"]},
                       %{
                         "tuple" => [
                           ":key3",
                           %{
                             ":max_expiration" => 31_536_000,
                             ":max_option_chars" => 200,
                             ":max_options" => 20,
                             ":min_expiration" => 0,
                             "nested" => %{
                               ":max_expiration" => 31_536_000,
                               ":max_option_chars" => 200,
                               ":max_options" => 20,
                               ":min_expiration" => 0
                             }
                           }
                         ]
                       }
                     ],
                     "db" => [":key2", ":key3"]
                   }
                 ],
                 "need_reboot" => false
               }
    end

    test "value as map", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{
              "group" => ":pleroma",
              "key" => ":key1",
              "value" => %{"key" => "some_val"}
            }
          ]
        })

      assert json_response_and_validate_schema(conn, 200) ==
               %{
                 "configs" => [
                   %{
                     "group" => ":pleroma",
                     "key" => ":key1",
                     "value" => %{"key" => "some_val"},
                     "db" => [":key1"]
                   }
                 ],
                 "need_reboot" => false
               }
    end

    test "queues key as atom", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{
              "group" => ":oban",
              "key" => ":queues",
              "value" => [
                %{"tuple" => [":federator_incoming", 50]},
                %{"tuple" => [":federator_outgoing", 50]},
                %{"tuple" => [":web_push", 50]},
                %{"tuple" => [":mailer", 10]},
                %{"tuple" => [":transmogrifier", 20]},
                %{"tuple" => [":scheduled_activities", 10]},
                %{"tuple" => [":background", 5]}
              ]
            }
          ]
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":oban",
                   "key" => ":queues",
                   "value" => [
                     %{"tuple" => [":federator_incoming", 50]},
                     %{"tuple" => [":federator_outgoing", 50]},
                     %{"tuple" => [":web_push", 50]},
                     %{"tuple" => [":mailer", 10]},
                     %{"tuple" => [":transmogrifier", 20]},
                     %{"tuple" => [":scheduled_activities", 10]},
                     %{"tuple" => [":background", 5]}
                   ],
                   "db" => [
                     ":federator_incoming",
                     ":federator_outgoing",
                     ":web_push",
                     ":mailer",
                     ":transmogrifier",
                     ":scheduled_activities",
                     ":background"
                   ]
                 }
               ],
               "need_reboot" => false
             }
    end

    test "delete part of settings by atom subkeys", %{conn: conn} do
      insert(:config,
        key: :keyaa1,
        value: [subkey1: "val1", subkey2: "val2", subkey3: "val3"]
      )

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{
              group: ":pleroma",
              key: ":keyaa1",
              subkeys: [":subkey1", ":subkey3"],
              delete: true
            }
          ]
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":keyaa1",
                   "value" => [%{"tuple" => [":subkey2", "val2"]}],
                   "db" => [":subkey2"]
                 }
               ],
               "need_reboot" => false
             }
    end

    test "proxy tuple localhost", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{
              group: ":pleroma",
              key: ":http",
              value: [
                %{"tuple" => [":proxy_url", %{"tuple" => [":socks5", "localhost", 1234]}]}
              ]
            }
          ]
        })

      assert %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":http",
                   "value" => value,
                   "db" => db
                 }
               ]
             } = json_response_and_validate_schema(conn, 200)

      assert %{"tuple" => [":proxy_url", %{"tuple" => [":socks5", "localhost", 1234]}]} in value
      assert ":proxy_url" in db
    end

    test "proxy tuple domain", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{
              group: ":pleroma",
              key: ":http",
              value: [
                %{"tuple" => [":proxy_url", %{"tuple" => [":socks5", "domain.com", 1234]}]}
              ]
            }
          ]
        })

      assert %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":http",
                   "value" => value,
                   "db" => db
                 }
               ]
             } = json_response_and_validate_schema(conn, 200)

      assert %{"tuple" => [":proxy_url", %{"tuple" => [":socks5", "domain.com", 1234]}]} in value
      assert ":proxy_url" in db
    end

    test "proxy tuple ip", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/admin/config", %{
          configs: [
            %{
              group: ":pleroma",
              key: ":http",
              value: [
                %{"tuple" => [":proxy_url", %{"tuple" => [":socks5", "127.0.0.1", 1234]}]}
              ]
            }
          ]
        })

      assert %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => ":http",
                   "value" => value,
                   "db" => db
                 }
               ]
             } = json_response_and_validate_schema(conn, 200)

      assert %{"tuple" => [":proxy_url", %{"tuple" => [":socks5", "127.0.0.1", 1234]}]} in value
      assert ":proxy_url" in db
    end

    @tag capture_log: true
    test "doesn't set keys not in the whitelist", %{conn: conn} do
      clear_config(:database_config_whitelist, [
        {:pleroma, :key1},
        {:pleroma, :key2},
        {:pleroma, Pleroma.Captcha.NotReal},
        {:not_real}
      ])

      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/pleroma/admin/config", %{
        configs: [
          %{group: ":pleroma", key: ":key1", value: "value1"},
          %{group: ":pleroma", key: ":key2", value: "value2"},
          %{group: ":pleroma", key: ":key3", value: "value3"},
          %{group: ":pleroma", key: "Pleroma.Web.Endpoint.NotReal", value: "value4"},
          %{group: ":pleroma", key: "Pleroma.Captcha.NotReal", value: "value5"},
          %{group: ":not_real", key: ":anything", value: "value6"}
        ]
      })

      assert Application.get_env(:pleroma, :key1) == "value1"
      assert Application.get_env(:pleroma, :key2) == "value2"
      assert Application.get_env(:pleroma, :key3) == nil
      assert Application.get_env(:pleroma, Pleroma.Web.Endpoint.NotReal) == nil
      assert Application.get_env(:pleroma, Pleroma.Captcha.NotReal) == "value5"
      assert Application.get_env(:not_real, :anything) == "value6"
    end

    test "args for Pleroma.Upload.Filter.Mogrify with custom tuples", %{conn: conn} do
      clear_config(Pleroma.Upload.Filter.Mogrify)

      assert conn
             |> put_req_header("content-type", "application/json")
             |> post("/api/pleroma/admin/config", %{
               configs: [
                 %{
                   group: ":pleroma",
                   key: "Pleroma.Upload.Filter.Mogrify",
                   value: [
                     %{"tuple" => [":args", ["auto-orient", "strip"]]}
                   ]
                 }
               ]
             })
             |> json_response_and_validate_schema(200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => "Pleroma.Upload.Filter.Mogrify",
                   "value" => [
                     %{"tuple" => [":args", ["auto-orient", "strip"]]}
                   ],
                   "db" => [":args"]
                 }
               ],
               "need_reboot" => false
             }

      assert Config.get(Pleroma.Upload.Filter.Mogrify) == [args: ["auto-orient", "strip"]]

      assert conn
             |> put_req_header("content-type", "application/json")
             |> post("/api/pleroma/admin/config", %{
               configs: [
                 %{
                   group: ":pleroma",
                   key: "Pleroma.Upload.Filter.Mogrify",
                   value: [
                     %{
                       "tuple" => [
                         ":args",
                         [
                           "auto-orient",
                           "strip",
                           "{\"implode\", \"1\"}",
                           "{\"resize\", \"3840x1080>\"}"
                         ]
                       ]
                     }
                   ]
                 }
               ]
             })
             |> json_response(200) == %{
               "configs" => [
                 %{
                   "group" => ":pleroma",
                   "key" => "Pleroma.Upload.Filter.Mogrify",
                   "value" => [
                     %{
                       "tuple" => [
                         ":args",
                         [
                           "auto-orient",
                           "strip",
                           "{\"implode\", \"1\"}",
                           "{\"resize\", \"3840x1080>\"}"
                         ]
                       ]
                     }
                   ],
                   "db" => [":args"]
                 }
               ],
               "need_reboot" => false
             }

      assert Config.get(Pleroma.Upload.Filter.Mogrify) == [
               args: ["auto-orient", "strip", {"implode", "1"}, {"resize", "3840x1080>"}]
             ]
    end

    test "enables the welcome messages", %{conn: conn} do
      clear_config([:welcome])

      params = %{
        "group" => ":pleroma",
        "key" => ":welcome",
        "value" => [
          %{
            "tuple" => [
              ":direct_message",
              [
                %{"tuple" => [":enabled", true]},
                %{"tuple" => [":message", "Welcome to Pleroma!"]},
                %{"tuple" => [":sender_nickname", "pleroma"]}
              ]
            ]
          },
          %{
            "tuple" => [
              ":chat_message",
              [
                %{"tuple" => [":enabled", true]},
                %{"tuple" => [":message", "Welcome to Pleroma!"]},
                %{"tuple" => [":sender_nickname", "pleroma"]}
              ]
            ]
          },
          %{
            "tuple" => [
              ":email",
              [
                %{"tuple" => [":enabled", true]},
                %{"tuple" => [":sender", %{"tuple" => ["pleroma@dev.dev", "Pleroma"]}]},
                %{"tuple" => [":subject", "Welcome to <%= instance_name %>!"]},
                %{"tuple" => [":html", "Welcome to <%= instance_name %>!"]},
                %{"tuple" => [":text", "Welcome to <%= instance_name %>!"]}
              ]
            ]
          }
        ]
      }

      refute Pleroma.User.WelcomeEmail.enabled?()
      refute Pleroma.User.WelcomeMessage.enabled?()
      refute Pleroma.User.WelcomeChatMessage.enabled?()

      res =
        assert conn
               |> put_req_header("content-type", "application/json")
               |> post("/api/pleroma/admin/config", %{"configs" => [params]})
               |> json_response_and_validate_schema(200)

      assert Pleroma.User.WelcomeEmail.enabled?()
      assert Pleroma.User.WelcomeMessage.enabled?()
      assert Pleroma.User.WelcomeChatMessage.enabled?()

      assert res == %{
               "configs" => [
                 %{
                   "db" => [":direct_message", ":chat_message", ":email"],
                   "group" => ":pleroma",
                   "key" => ":welcome",
                   "value" => params["value"]
                 }
               ],
               "need_reboot" => false
             }
    end

    test "custom instance thumbnail", %{conn: conn} do
      clear_config([:instance])

      params = %{
        "group" => ":pleroma",
        "key" => ":instance",
        "value" => [
          %{
            "tuple" => [
              ":instance_thumbnail",
              "https://example.com/media/new_thumbnail.jpg"
            ]
          }
        ]
      }

      assert conn
             |> put_req_header("content-type", "application/json")
             |> post("/api/pleroma/admin/config", %{"configs" => [params]})
             |> json_response_and_validate_schema(200) ==
               %{
                 "configs" => [
                   %{
                     "db" => [":instance_thumbnail"],
                     "group" => ":pleroma",
                     "key" => ":instance",
                     "value" => params["value"]
                   }
                 ],
                 "need_reboot" => false
               }

      assert conn
             |> get("/api/v1/instance")
             |> json_response_and_validate_schema(200)
             |> Map.take(["thumbnail"]) ==
               %{"thumbnail" => "https://example.com/media/new_thumbnail.jpg"}
    end

    test "Concurrent Limiter", %{conn: conn} do
      clear_config([ConcurrentLimiter])

      params = %{
        "group" => ":pleroma",
        "key" => "ConcurrentLimiter",
        "value" => [
          %{
            "tuple" => [
              "Pleroma.Web.RichMedia.Helpers",
              [
                %{"tuple" => [":max_running", 6]},
                %{"tuple" => [":max_waiting", 6]}
              ]
            ]
          },
          %{
            "tuple" => [
              "Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy",
              [
                %{"tuple" => [":max_running", 7]},
                %{"tuple" => [":max_waiting", 7]}
              ]
            ]
          }
        ]
      }

      assert conn
             |> put_req_header("content-type", "application/json")
             |> post("/api/pleroma/admin/config", %{"configs" => [params]})
             |> json_response_and_validate_schema(200)
    end
  end

  describe "GET /api/pleroma/admin/config/descriptions" do
    test "structure", %{conn: conn} do
      conn = get(conn, "/api/pleroma/admin/config/descriptions")

      assert [child | _others] = json_response_and_validate_schema(conn, 200)

      assert child["children"]
      assert child["key"]
      assert String.starts_with?(child["group"], ":")
      assert child["description"]
    end

    test "filters by database configuration whitelist", %{conn: conn} do
      clear_config(:database_config_whitelist, [
        {:pleroma, :instance},
        {:pleroma, :activitypub},
        {:pleroma, Pleroma.Upload},
        {:esshd}
      ])

      conn = get(conn, "/api/pleroma/admin/config/descriptions")

      children = json_response_and_validate_schema(conn, 200)

      assert length(children) == 4

      assert Enum.count(children, fn c -> c["group"] == ":pleroma" end) == 3

      instance = Enum.find(children, fn c -> c["key"] == ":instance" end)
      assert instance["children"]

      activitypub = Enum.find(children, fn c -> c["key"] == ":activitypub" end)
      assert activitypub["children"]

      web_endpoint = Enum.find(children, fn c -> c["key"] == "Pleroma.Upload" end)
      assert web_endpoint["children"]

      esshd = Enum.find(children, fn c -> c["group"] == ":esshd" end)
      assert esshd["children"]
    end
  end
end
