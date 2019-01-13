# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.Connection do
  @moduledoc """
  Connection for http-requests.
  """

  @hackney_options [
    timeout: 10000,
    recv_timeout: 20000,
    follow_redirect: true
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
  defp hackney_options(opts) do
    options = Keyword.get(opts, :adapter, [])
    @hackney_options ++ options
  end
end
