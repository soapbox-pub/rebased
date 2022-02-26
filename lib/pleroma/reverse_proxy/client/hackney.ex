# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ReverseProxy.Client.Hackney do
  @behaviour Pleroma.ReverseProxy.Client

  @impl true
  def request(method, url, headers, body, opts \\ []) do
    opts = Keyword.put(opts, :ssl_options, versions: [:"tlsv1.2", :"tlsv1.1", :tlsv1])
    :hackney.request(method, url, headers, body, opts)
  end

  @impl true
  def stream_body(ref) do
    case :hackney.stream_body(ref) do
      :done -> :done
      {:ok, data} -> {:ok, data, ref}
      {:error, error} -> {:error, error}
    end
  end

  @impl true
  def close(ref), do: :hackney.close(ref)
end
