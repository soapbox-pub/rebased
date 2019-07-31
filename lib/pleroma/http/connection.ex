# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.Connection do
  @moduledoc """
  Connection for http-requests.
  """

  @hackney_options [
    connect_timeout: 10_000,
    recv_timeout: 20_000,
    follow_redirect: true,
    force_redirect: true,
    pool: :federation
  ]
  @adapter Application.get_env(:tesla, :adapter)

  @doc """
  Configure a client connection

  # Returns

  Tesla.Env.client
  """
  @spec new(Keyword.t()) :: Tesla.Env.client()
  def new(opts \\ []) do
    Tesla.client([], {@adapter, hackney_options(opts)})
  end

  # fetch Hackney options
  #
  def hackney_options(opts) do
    options = Keyword.get(opts, :adapter, [])
    adapter_options = Pleroma.Config.get([:http, :adapter], [])
    proxy_url = Pleroma.Config.get([:http, :proxy_url], nil)

    @hackney_options
    |> Keyword.merge(adapter_options)
    |> Keyword.merge(options)
    |> Keyword.merge(proxy: proxy_url)
  end
end
