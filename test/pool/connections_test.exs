# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Pool.ConnectionsTest do
  use ExUnit.Case
  use Pleroma.Tests.Helpers
  import ExUnit.CaptureLog
  alias Pleroma.Gun.Conn
  alias Pleroma.Pool.Connections

  setup_all do
    {:ok, _} = Registry.start_link(keys: :unique, name: Pleroma.GunMock)
    :ok
  end

  clear_config([:connections_pool, :retry]) do
    Pleroma.Config.put([:connections_pool, :retry], 5)
  end

  setup do
    name = :test_connections
    adapter = Application.get_env(:tesla, :adapter)
    Application.put_env(:tesla, :adapter, Tesla.Adapter.Gun)

    {:ok, pid} = Connections.start_link({name, [max_connections: 2, checkin_timeout: 1_500]})

    on_exit(fn ->
      Application.put_env(:tesla, :adapter, adapter)

      if Process.alive?(pid) do
        GenServer.stop(name)
      end
    end)

    {:ok, name: name}
  end

  describe "alive?/2" do
    test "is alive", %{name: name} do
      assert Connections.alive?(name)
    end

    test "returns false if not started" do
      refute Connections.alive?(:some_random_name)
    end
  end

  test "opens connection and reuse it on next request", %{name: name} do
    url = "http://some-domain.com"
    key = "http:some-domain.com:80"
    refute Connections.checkin(url, name)
    :ok = Conn.open(url, name)

    conn = Connections.checkin(url, name)
    assert is_pid(conn)
    assert Process.alive?(conn)

    self = self()

    %Connections{
      conns: %{
        ^key => %Conn{
          conn: ^conn,
          gun_state: :up,
          used_by: [{^self, _}],
          conn_state: :active
        }
      }
    } = Connections.get_state(name)

    reused_conn = Connections.checkin(url, name)

    assert conn == reused_conn

    %Connections{
      conns: %{
        ^key => %Conn{
          conn: ^conn,
          gun_state: :up,
          used_by: [{^self, _}, {^self, _}],
          conn_state: :active
        }
      }
    } = Connections.get_state(name)

    :ok = Connections.checkout(conn, self, name)

    %Connections{
      conns: %{
        ^key => %Conn{
          conn: ^conn,
          gun_state: :up,
          used_by: [{^self, _}],
          conn_state: :active
        }
      }
    } = Connections.get_state(name)

    :ok = Connections.checkout(conn, self, name)

    %Connections{
      conns: %{
        ^key => %Conn{
          conn: ^conn,
          gun_state: :up,
          used_by: [],
          conn_state: :idle
        }
      }
    } = Connections.get_state(name)
  end

  test "reuse connection for idna domains", %{name: name} do
    url = "http://ですsome-domain.com"
    refute Connections.checkin(url, name)

    :ok = Conn.open(url, name)

    conn = Connections.checkin(url, name)
    assert is_pid(conn)
    assert Process.alive?(conn)

    self = self()

    %Connections{
      conns: %{
        "http:ですsome-domain.com:80" => %Conn{
          conn: ^conn,
          gun_state: :up,
          used_by: [{^self, _}],
          conn_state: :active
        }
      }
    } = Connections.get_state(name)

    reused_conn = Connections.checkin(url, name)

    assert conn == reused_conn
  end

  test "reuse for ipv4", %{name: name} do
    url = "http://127.0.0.1"

    refute Connections.checkin(url, name)

    :ok = Conn.open(url, name)

    conn = Connections.checkin(url, name)
    assert is_pid(conn)
    assert Process.alive?(conn)

    self = self()

    %Connections{
      conns: %{
        "http:127.0.0.1:80" => %Conn{
          conn: ^conn,
          gun_state: :up,
          used_by: [{^self, _}],
          conn_state: :active
        }
      }
    } = Connections.get_state(name)

    reused_conn = Connections.checkin(url, name)

    assert conn == reused_conn

    :ok = Connections.checkout(conn, self, name)
    :ok = Connections.checkout(reused_conn, self, name)

    %Connections{
      conns: %{
        "http:127.0.0.1:80" => %Conn{
          conn: ^conn,
          gun_state: :up,
          used_by: [],
          conn_state: :idle
        }
      }
    } = Connections.get_state(name)
  end

  test "reuse for ipv6", %{name: name} do
    url = "http://[2a03:2880:f10c:83:face:b00c:0:25de]"

    refute Connections.checkin(url, name)

    :ok = Conn.open(url, name)

    conn = Connections.checkin(url, name)
    assert is_pid(conn)
    assert Process.alive?(conn)

    self = self()

    %Connections{
      conns: %{
        "http:2a03:2880:f10c:83:face:b00c:0:25de:80" => %Conn{
          conn: ^conn,
          gun_state: :up,
          used_by: [{^self, _}],
          conn_state: :active
        }
      }
    } = Connections.get_state(name)

    reused_conn = Connections.checkin(url, name)

    assert conn == reused_conn
  end

  test "up and down ipv4", %{name: name} do
    self = self()
    url = "http://127.0.0.1"
    :ok = Conn.open(url, name)
    conn = Connections.checkin(url, name)
    send(name, {:gun_down, conn, nil, nil, nil})
    send(name, {:gun_up, conn, nil})

    %Connections{
      conns: %{
        "http:127.0.0.1:80" => %Conn{
          conn: ^conn,
          gun_state: :up,
          used_by: [{^self, _}],
          conn_state: :active
        }
      }
    } = Connections.get_state(name)
  end

  test "up and down ipv6", %{name: name} do
    self = self()
    url = "http://[2a03:2880:f10c:83:face:b00c:0:25de]"
    :ok = Conn.open(url, name)
    conn = Connections.checkin(url, name)
    send(name, {:gun_down, conn, nil, nil, nil})
    send(name, {:gun_up, conn, nil})

    %Connections{
      conns: %{
        "http:2a03:2880:f10c:83:face:b00c:0:25de:80" => %Conn{
          conn: ^conn,
          gun_state: :up,
          used_by: [{^self, _}],
          conn_state: :active
        }
      }
    } = Connections.get_state(name)
  end

  test "reuses connection based on protocol", %{name: name} do
    http_url = "http://some-domain.com"
    http_key = "http:some-domain.com:80"
    https_url = "https://some-domain.com"
    https_key = "https:some-domain.com:443"

    refute Connections.checkin(http_url, name)
    :ok = Conn.open(http_url, name)
    conn = Connections.checkin(http_url, name)
    assert is_pid(conn)
    assert Process.alive?(conn)

    refute Connections.checkin(https_url, name)
    :ok = Conn.open(https_url, name)
    https_conn = Connections.checkin(https_url, name)

    refute conn == https_conn

    reused_https = Connections.checkin(https_url, name)

    refute conn == reused_https

    assert reused_https == https_conn

    %Connections{
      conns: %{
        ^http_key => %Conn{
          conn: ^conn,
          gun_state: :up
        },
        ^https_key => %Conn{
          conn: ^https_conn,
          gun_state: :up
        }
      }
    } = Connections.get_state(name)
  end

  test "connection can't get up", %{name: name} do
    url = "http://gun-not-up.com"

    assert capture_log(fn ->
             refute Conn.open(url, name)
             refute Connections.checkin(url, name)
           end) =~
             "Received error on opening connection http://gun-not-up.com {:error, :timeout}"
  end

  test "process gun_down message and then gun_up", %{name: name} do
    self = self()
    url = "http://gun-down-and-up.com"
    key = "http:gun-down-and-up.com:80"
    :ok = Conn.open(url, name)
    conn = Connections.checkin(url, name)

    assert is_pid(conn)
    assert Process.alive?(conn)

    %Connections{
      conns: %{
        ^key => %Conn{
          conn: ^conn,
          gun_state: :up,
          used_by: [{^self, _}]
        }
      }
    } = Connections.get_state(name)

    send(name, {:gun_down, conn, :http, nil, nil})

    %Connections{
      conns: %{
        ^key => %Conn{
          conn: ^conn,
          gun_state: :down,
          used_by: [{^self, _}]
        }
      }
    } = Connections.get_state(name)

    send(name, {:gun_up, conn, :http})

    conn2 = Connections.checkin(url, name)
    assert conn == conn2

    assert is_pid(conn2)
    assert Process.alive?(conn2)

    %Connections{
      conns: %{
        ^key => %Conn{
          conn: _,
          gun_state: :up,
          used_by: [{^self, _}, {^self, _}]
        }
      }
    } = Connections.get_state(name)
  end

  test "async processes get same conn for same domain", %{name: name} do
    url = "http://some-domain.com"
    :ok = Conn.open(url, name)

    tasks =
      for _ <- 1..5 do
        Task.async(fn ->
          Connections.checkin(url, name)
        end)
      end

    tasks_with_results = Task.yield_many(tasks)

    results =
      Enum.map(tasks_with_results, fn {task, res} ->
        res || Task.shutdown(task, :brutal_kill)
      end)

    conns = for {:ok, value} <- results, do: value

    %Connections{
      conns: %{
        "http:some-domain.com:80" => %Conn{
          conn: conn,
          gun_state: :up
        }
      }
    } = Connections.get_state(name)

    assert Enum.all?(conns, fn res -> res == conn end)
  end

  test "remove frequently used and idle", %{name: name} do
    self = self()
    http_url = "http://some-domain.com"
    https_url = "https://some-domain.com"
    :ok = Conn.open(https_url, name)
    :ok = Conn.open(http_url, name)

    conn1 = Connections.checkin(https_url, name)

    [conn2 | _conns] =
      for _ <- 1..4 do
        Connections.checkin(http_url, name)
      end

    http_key = "http:some-domain.com:80"

    %Connections{
      conns: %{
        ^http_key => %Conn{
          conn: ^conn2,
          gun_state: :up,
          conn_state: :active,
          used_by: [{^self, _}, {^self, _}, {^self, _}, {^self, _}]
        },
        "https:some-domain.com:443" => %Conn{
          conn: ^conn1,
          gun_state: :up,
          conn_state: :active,
          used_by: [{^self, _}]
        }
      }
    } = Connections.get_state(name)

    :ok = Connections.checkout(conn1, self, name)

    another_url = "http://another-domain.com"
    :ok = Conn.open(another_url, name)
    conn = Connections.checkin(another_url, name)

    %Connections{
      conns: %{
        "http:another-domain.com:80" => %Conn{
          conn: ^conn,
          gun_state: :up
        },
        ^http_key => %Conn{
          conn: _,
          gun_state: :up
        }
      }
    } = Connections.get_state(name)
  end

  describe "with proxy" do
    test "as ip", %{name: name} do
      url = "http://proxy-string.com"
      key = "http:proxy-string.com:80"
      :ok = Conn.open(url, name, proxy: {{127, 0, 0, 1}, 8123})

      conn = Connections.checkin(url, name)

      %Connections{
        conns: %{
          ^key => %Conn{
            conn: ^conn,
            gun_state: :up
          }
        }
      } = Connections.get_state(name)

      reused_conn = Connections.checkin(url, name)

      assert reused_conn == conn
    end

    test "as host", %{name: name} do
      url = "http://proxy-tuple-atom.com"
      :ok = Conn.open(url, name, proxy: {'localhost', 9050})
      conn = Connections.checkin(url, name)

      %Connections{
        conns: %{
          "http:proxy-tuple-atom.com:80" => %Conn{
            conn: ^conn,
            gun_state: :up
          }
        }
      } = Connections.get_state(name)

      reused_conn = Connections.checkin(url, name)

      assert reused_conn == conn
    end

    test "as ip and ssl", %{name: name} do
      url = "https://proxy-string.com"

      :ok = Conn.open(url, name, proxy: {{127, 0, 0, 1}, 8123})
      conn = Connections.checkin(url, name)

      %Connections{
        conns: %{
          "https:proxy-string.com:443" => %Conn{
            conn: ^conn,
            gun_state: :up
          }
        }
      } = Connections.get_state(name)

      reused_conn = Connections.checkin(url, name)

      assert reused_conn == conn
    end

    test "as host and ssl", %{name: name} do
      url = "https://proxy-tuple-atom.com"
      :ok = Conn.open(url, name, proxy: {'localhost', 9050})
      conn = Connections.checkin(url, name)

      %Connections{
        conns: %{
          "https:proxy-tuple-atom.com:443" => %Conn{
            conn: ^conn,
            gun_state: :up
          }
        }
      } = Connections.get_state(name)

      reused_conn = Connections.checkin(url, name)

      assert reused_conn == conn
    end

    test "with socks type", %{name: name} do
      url = "http://proxy-socks.com"

      :ok = Conn.open(url, name, proxy: {:socks5, 'localhost', 1234})

      conn = Connections.checkin(url, name)

      %Connections{
        conns: %{
          "http:proxy-socks.com:80" => %Conn{
            conn: ^conn,
            gun_state: :up
          }
        }
      } = Connections.get_state(name)

      reused_conn = Connections.checkin(url, name)

      assert reused_conn == conn
    end

    test "with socks4 type and ssl", %{name: name} do
      url = "https://proxy-socks.com"

      :ok = Conn.open(url, name, proxy: {:socks4, 'localhost', 1234})

      conn = Connections.checkin(url, name)

      %Connections{
        conns: %{
          "https:proxy-socks.com:443" => %Conn{
            conn: ^conn,
            gun_state: :up
          }
        }
      } = Connections.get_state(name)

      reused_conn = Connections.checkin(url, name)

      assert reused_conn == conn
    end
  end

  describe "crf/3" do
    setup do
      crf = Connections.crf(1, 10, 1)
      {:ok, crf: crf}
    end

    test "more used will have crf higher", %{crf: crf} do
      # used 3 times
      crf1 = Connections.crf(1, 10, crf)
      crf1 = Connections.crf(1, 10, crf1)

      # used 2 times
      crf2 = Connections.crf(1, 10, crf)

      assert crf1 > crf2
    end

    test "recently used will have crf higher on equal references", %{crf: crf} do
      # used 3 sec ago
      crf1 = Connections.crf(3, 10, crf)

      # used 4 sec ago
      crf2 = Connections.crf(4, 10, crf)

      assert crf1 > crf2
    end

    test "equal crf on equal reference and time", %{crf: crf} do
      # used 2 times
      crf1 = Connections.crf(1, 10, crf)

      # used 2 times
      crf2 = Connections.crf(1, 10, crf)

      assert crf1 == crf2
    end

    test "recently used will have higher crf", %{crf: crf} do
      crf1 = Connections.crf(2, 10, crf)
      crf1 = Connections.crf(1, 10, crf1)

      crf2 = Connections.crf(3, 10, crf)
      crf2 = Connections.crf(4, 10, crf2)
      assert crf1 > crf2
    end
  end

  describe "get_unused_conns/1" do
    test "crf is equalent, sorting by reference", %{name: name} do
      Connections.add_conn(name, "1", %Conn{
        conn_state: :idle,
        last_reference: now() - 1
      })

      Connections.add_conn(name, "2", %Conn{
        conn_state: :idle,
        last_reference: now()
      })

      assert [{"1", _unused_conn} | _others] = Connections.get_unused_conns(name)
    end

    test "reference is equalent, sorting by crf", %{name: name} do
      Connections.add_conn(name, "1", %Conn{
        conn_state: :idle,
        crf: 1.999
      })

      Connections.add_conn(name, "2", %Conn{
        conn_state: :idle,
        crf: 2
      })

      assert [{"1", _unused_conn} | _others] = Connections.get_unused_conns(name)
    end

    test "higher crf and lower reference", %{name: name} do
      Connections.add_conn(name, "1", %Conn{
        conn_state: :idle,
        crf: 3,
        last_reference: now() - 1
      })

      Connections.add_conn(name, "2", %Conn{
        conn_state: :idle,
        crf: 2,
        last_reference: now()
      })

      assert [{"2", _unused_conn} | _others] = Connections.get_unused_conns(name)
    end

    test "lower crf and lower reference", %{name: name} do
      Connections.add_conn(name, "1", %Conn{
        conn_state: :idle,
        crf: 1.99,
        last_reference: now() - 1
      })

      Connections.add_conn(name, "2", %Conn{
        conn_state: :idle,
        crf: 2,
        last_reference: now()
      })

      assert [{"1", _unused_conn} | _others] = Connections.get_unused_conns(name)
    end
  end

  test "count/1", %{name: name} do
    assert Connections.count(name) == 0
    Connections.add_conn(name, "1", %Conn{conn: self()})
    assert Connections.count(name) == 1
    Connections.remove_conn(name, "1")
    assert Connections.count(name) == 0
  end

  defp now do
    :os.system_time(:second)
  end
end
