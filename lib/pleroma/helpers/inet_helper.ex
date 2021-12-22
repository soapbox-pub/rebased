# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Helpers.InetHelper do
  def parse_address(ip) when is_tuple(ip) do
    {:ok, ip}
  end

  def parse_address(ip) when is_binary(ip) do
    ip
    |> String.to_charlist()
    |> parse_address()
  end

  def parse_address(ip) do
    :inet.parse_address(ip)
  end
end
