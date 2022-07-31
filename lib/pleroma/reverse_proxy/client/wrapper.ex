# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ReverseProxy.Client.Wrapper do
  @moduledoc "Meta-client that calls the appropriate client from the config."
  @behaviour Pleroma.ReverseProxy.Client

  @impl true
  def request(method, url, headers, body \\ "", opts \\ []) do
    client().request(method, url, headers, body, opts)
  end

  @impl true
  def stream_body(ref), do: client().stream_body(ref)

  @impl true
  def close(ref), do: client().close(ref)

  defp client do
    :tesla
    |> Application.get_env(:adapter)
    |> client()
  end

  defp client(Tesla.Adapter.Hackney), do: Pleroma.ReverseProxy.Client.Hackney
  defp client(Tesla.Adapter.Gun), do: Pleroma.ReverseProxy.Client.Tesla
  defp client({Tesla.Adapter.Finch, _}), do: Pleroma.ReverseProxy.Client.Hackney
  defp client(_), do: Pleroma.Config.get!(Pleroma.ReverseProxy.Client)
end
