# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ReverseProxyTest do
  use Pleroma.Web.ConnCase, async: true
  import ExUnit.CaptureLog
  import Mox
  alias Pleroma.ReverseProxy
  alias Pleroma.ReverseProxy.ClientMock

  setup_all do
    {:ok, _} = Registry.start_link(keys: :unique, name: Pleroma.ReverseProxy.ClientMock)
    :ok
  end

  setup :verify_on_exit!

  defp user_agent_mock(user_agent, invokes) do
    json = Jason.encode!(%{"user-agent": user_agent})

    ClientMock
    |> expect(:request, fn :get, url, _, _, _ ->
      Registry.register(Pleroma.ReverseProxy.ClientMock, url, 0)

      {:ok, 200,
       [
         {"content-type", "application/json"},
         {"content-length", byte_size(json) |> to_string()}
       ], %{url: url}}
    end)
    |> expect(:stream_body, invokes, fn %{url: url} ->
      case Registry.lookup(Pleroma.ReverseProxy.ClientMock, url) do
        [{_, 0}] ->
          Registry.update_value(Pleroma.ReverseProxy.ClientMock, url, &(&1 + 1))
          {:ok, json}

        [{_, 1}] ->
          Registry.unregister(Pleroma.ReverseProxy.ClientMock, url)
          :done
      end
    end)
  end

  describe "reverse proxy" do
    test "do not track successful request", %{conn: conn} do
      user_agent_mock("hackney/1.15.1", 2)
      url = "/success"

      conn = ReverseProxy.call(conn, url)

      assert conn.status == 200
      assert Cachex.get(:failed_proxy_url_cache, url) == {:ok, nil}
    end
  end

  describe "user-agent" do
    test "don't keep", %{conn: conn} do
      user_agent_mock("hackney/1.15.1", 2)
      conn = ReverseProxy.call(conn, "/user-agent")
      assert json_response(conn, 200) == %{"user-agent" => "hackney/1.15.1"}
    end

    test "keep", %{conn: conn} do
      user_agent_mock(Pleroma.Application.user_agent(), 2)
      conn = ReverseProxy.call(conn, "/user-agent-keep", keep_user_agent: true)
      assert json_response(conn, 200) == %{"user-agent" => Pleroma.Application.user_agent()}
    end
  end

  test "closed connection", %{conn: conn} do
    ClientMock
    |> expect(:request, fn :get, "/closed", _, _, _ -> {:ok, 200, [], %{}} end)
    |> expect(:stream_body, fn _ -> {:error, :closed} end)
    |> expect(:close, fn _ -> :ok end)

    conn = ReverseProxy.call(conn, "/closed")
    assert conn.halted
  end

  describe "max_body " do
    test "length returns error if content-length more than option", %{conn: conn} do
      user_agent_mock("hackney/1.15.1", 0)

      assert capture_log(fn ->
               ReverseProxy.call(conn, "/huge-file", max_body_length: 4)
             end) =~
               "[error] Elixir.Pleroma.ReverseProxy: request to \"/huge-file\" failed: :body_too_large"

      assert {:ok, true} == Cachex.get(:failed_proxy_url_cache, "/huge-file")

      assert capture_log(fn ->
               ReverseProxy.call(conn, "/huge-file", max_body_length: 4)
             end) == ""
    end

    defp stream_mock(invokes, with_close? \\ false) do
      ClientMock
      |> expect(:request, fn :get, "/stream-bytes/" <> length, _, _, _ ->
        Registry.register(Pleroma.ReverseProxy.ClientMock, "/stream-bytes/" <> length, 0)

        {:ok, 200, [{"content-type", "application/octet-stream"}],
         %{url: "/stream-bytes/" <> length}}
      end)
      |> expect(:stream_body, invokes, fn %{url: "/stream-bytes/" <> length} ->
        max = String.to_integer(length)

        case Registry.lookup(Pleroma.ReverseProxy.ClientMock, "/stream-bytes/" <> length) do
          [{_, current}] when current < max ->
            Registry.update_value(
              Pleroma.ReverseProxy.ClientMock,
              "/stream-bytes/" <> length,
              &(&1 + 10)
            )

            {:ok, "0123456789"}

          [{_, ^max}] ->
            Registry.unregister(Pleroma.ReverseProxy.ClientMock, "/stream-bytes/" <> length)
            :done
        end
      end)

      if with_close? do
        expect(ClientMock, :close, fn _ -> :ok end)
      end
    end

    test "max_body_length returns error if streaming body more than that option", %{conn: conn} do
      stream_mock(3, true)

      assert capture_log(fn ->
               ReverseProxy.call(conn, "/stream-bytes/50", max_body_length: 30)
             end) =~
               "[warn] Elixir.Pleroma.ReverseProxy request to /stream-bytes/50 failed while reading/chunking: :body_too_large"
    end
  end

  describe "HEAD requests" do
    test "common", %{conn: conn} do
      ClientMock
      |> expect(:request, fn :head, "/head", _, _, _ ->
        {:ok, 200, [{"content-type", "text/html; charset=utf-8"}]}
      end)

      conn = ReverseProxy.call(Map.put(conn, :method, "HEAD"), "/head")
      assert html_response(conn, 200) == ""
    end
  end

  defp error_mock(status) when is_integer(status) do
    ClientMock
    |> expect(:request, fn :get, "/status/" <> _, _, _, _ ->
      {:error, status}
    end)
  end

  describe "returns error on" do
    test "500", %{conn: conn} do
      error_mock(500)
      url = "/status/500"

      capture_log(fn -> ReverseProxy.call(conn, url) end) =~
        "[error] Elixir.Pleroma.ReverseProxy: request to /status/500 failed with HTTP status 500"

      assert Cachex.get(:failed_proxy_url_cache, url) == {:ok, true}

      {:ok, ttl} = Cachex.ttl(:failed_proxy_url_cache, url)
      assert ttl <= 60_000
    end

    test "400", %{conn: conn} do
      error_mock(400)
      url = "/status/400"

      capture_log(fn -> ReverseProxy.call(conn, url) end) =~
        "[error] Elixir.Pleroma.ReverseProxy: request to /status/400 failed with HTTP status 400"

      assert Cachex.get(:failed_proxy_url_cache, url) == {:ok, true}
      assert Cachex.ttl(:failed_proxy_url_cache, url) == {:ok, nil}
    end

    test "403", %{conn: conn} do
      error_mock(403)
      url = "/status/403"

      capture_log(fn ->
        ReverseProxy.call(conn, url, failed_request_ttl: :timer.seconds(120))
      end) =~
        "[error] Elixir.Pleroma.ReverseProxy: request to /status/403 failed with HTTP status 403"

      {:ok, ttl} = Cachex.ttl(:failed_proxy_url_cache, url)
      assert ttl > 100_000
    end

    test "204", %{conn: conn} do
      url = "/status/204"
      expect(ClientMock, :request, fn :get, _url, _, _, _ -> {:ok, 204, [], %{}} end)

      capture_log(fn ->
        conn = ReverseProxy.call(conn, url)
        assert conn.resp_body == "Request failed: No Content"
        assert conn.halted
      end) =~
        "[error] Elixir.Pleroma.ReverseProxy: request to \"/status/204\" failed with HTTP status 204"

      assert Cachex.get(:failed_proxy_url_cache, url) == {:ok, true}
      assert Cachex.ttl(:failed_proxy_url_cache, url) == {:ok, nil}
    end
  end

  test "streaming", %{conn: conn} do
    stream_mock(21)
    conn = ReverseProxy.call(conn, "/stream-bytes/200")
    assert conn.state == :chunked
    assert byte_size(conn.resp_body) == 200
    assert Plug.Conn.get_resp_header(conn, "content-type") == ["application/octet-stream"]
  end

  defp headers_mock(_) do
    ClientMock
    |> expect(:request, fn :get, "/headers", headers, _, _ ->
      Registry.register(Pleroma.ReverseProxy.ClientMock, "/headers", 0)
      {:ok, 200, [{"content-type", "application/json"}], %{url: "/headers", headers: headers}}
    end)
    |> expect(:stream_body, 2, fn %{url: url, headers: headers} ->
      case Registry.lookup(Pleroma.ReverseProxy.ClientMock, url) do
        [{_, 0}] ->
          Registry.update_value(Pleroma.ReverseProxy.ClientMock, url, &(&1 + 1))
          headers = for {k, v} <- headers, into: %{}, do: {String.capitalize(k), v}
          {:ok, Jason.encode!(%{headers: headers})}

        [{_, 1}] ->
          Registry.unregister(Pleroma.ReverseProxy.ClientMock, url)
          :done
      end
    end)

    :ok
  end

  describe "keep request headers" do
    setup [:headers_mock]

    test "header passes", %{conn: conn} do
      conn =
        Plug.Conn.put_req_header(
          conn,
          "accept",
          "text/html"
        )
        |> ReverseProxy.call("/headers")

      %{"headers" => headers} = json_response(conn, 200)
      assert headers["Accept"] == "text/html"
    end

    test "header is filtered", %{conn: conn} do
      conn =
        Plug.Conn.put_req_header(
          conn,
          "accept-language",
          "en-US"
        )
        |> ReverseProxy.call("/headers")

      %{"headers" => headers} = json_response(conn, 200)
      refute headers["Accept-Language"]
    end
  end

  test "returns 400 on non GET, HEAD requests", %{conn: conn} do
    conn = ReverseProxy.call(Map.put(conn, :method, "POST"), "/ip")
    assert conn.status == 400
  end

  describe "cache resp headers" do
    test "add cache-control", %{conn: conn} do
      ClientMock
      |> expect(:request, fn :get, "/cache", _, _, _ ->
        {:ok, 200, [{"ETag", "some ETag"}], %{}}
      end)
      |> expect(:stream_body, fn _ -> :done end)

      conn = ReverseProxy.call(conn, "/cache")
      assert {"cache-control", "public, max-age=1209600"} in conn.resp_headers
    end
  end

  defp disposition_headers_mock(headers) do
    ClientMock
    |> expect(:request, fn :get, "/disposition", _, _, _ ->
      Registry.register(Pleroma.ReverseProxy.ClientMock, "/disposition", 0)

      {:ok, 200, headers, %{url: "/disposition"}}
    end)
    |> expect(:stream_body, 2, fn %{url: "/disposition"} ->
      case Registry.lookup(Pleroma.ReverseProxy.ClientMock, "/disposition") do
        [{_, 0}] ->
          Registry.update_value(Pleroma.ReverseProxy.ClientMock, "/disposition", &(&1 + 1))
          {:ok, ""}

        [{_, 1}] ->
          Registry.unregister(Pleroma.ReverseProxy.ClientMock, "/disposition")
          :done
      end
    end)
  end

  describe "response content disposition header" do
    test "not atachment", %{conn: conn} do
      disposition_headers_mock([
        {"content-type", "image/gif"},
        {"content-length", 0}
      ])

      conn = ReverseProxy.call(conn, "/disposition")

      assert {"content-type", "image/gif"} in conn.resp_headers
    end

    test "with content-disposition header", %{conn: conn} do
      disposition_headers_mock([
        {"content-disposition", "attachment; filename=\"filename.jpg\""},
        {"content-length", 0}
      ])

      conn = ReverseProxy.call(conn, "/disposition")

      assert {"content-disposition", "attachment; filename=\"filename.jpg\""} in conn.resp_headers
    end
  end
end
