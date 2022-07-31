# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Endpoint.MetricsExporterTest do
  # Modifies AppEnv, has to stay synchronous
  use Pleroma.Web.ConnCase

  alias Pleroma.Web.Endpoint.MetricsExporter

  defp config do
    Application.get_env(:prometheus, MetricsExporter)
  end

  describe "with default config" do
    test "does NOT expose app metrics", %{conn: conn} do
      conn
      |> get(config()[:path])
      |> json_response(404)
    end
  end

  describe "when enabled" do
    setup do
      initial_config = config()
      on_exit(fn -> Application.put_env(:prometheus, MetricsExporter, initial_config) end)

      Application.put_env(
        :prometheus,
        MetricsExporter,
        Keyword.put(initial_config, :enabled, true)
      )
    end

    test "serves app metrics", %{conn: conn} do
      conn = get(conn, config()[:path])
      assert response = response(conn, 200)

      for metric <- [
            "http_requests_total",
            "http_request_duration_microseconds",
            "phoenix_controller_call_duration",
            "telemetry_scrape_duration",
            "erlang_vm_memory_atom_bytes_total"
          ] do
        assert response =~ ~r/#{metric}/
      end
    end

    test "when IP whitelist configured, " <>
           "serves app metrics only if client IP is whitelisted",
         %{conn: conn} do
      Application.put_env(
        :prometheus,
        MetricsExporter,
        Keyword.put(config(), :ip_whitelist, ["127.127.127.127", {1, 1, 1, 1}, '255.255.255.255'])
      )

      conn
      |> get(config()[:path])
      |> json_response(404)

      conn
      |> Map.put(:remote_ip, {127, 127, 127, 127})
      |> get(config()[:path])
      |> response(200)
    end
  end
end
