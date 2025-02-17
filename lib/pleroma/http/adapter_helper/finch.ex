# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.AdapterHelper.Finch do
  @behaviour Pleroma.HTTP.AdapterHelper

  alias Pleroma.Config
  alias Pleroma.HTTP.AdapterHelper

  @spec options(keyword(), URI.t()) :: keyword()
  def options(incoming_opts \\ [], %URI{} = _uri) do
    proxy =
      [:http, :proxy_url]
      |> Config.get()
      |> AdapterHelper.format_proxy()

    config_opts = Config.get([:http, :adapter], [])

    config_opts
    |> Keyword.merge(incoming_opts)
    |> AdapterHelper.maybe_add_proxy(proxy)
    |> maybe_stream()
  end

  # Finch uses [response: :stream]
  defp maybe_stream(opts) do
    case Keyword.pop(opts, :stream, nil) do
      {true, opts} -> Keyword.put(opts, :response, :stream)
      {_, opts} -> opts
    end
  end
end
