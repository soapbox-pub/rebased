# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.AdapterHelper.Hackney do
  @behaviour Pleroma.HTTP.AdapterHelper

  @defaults [
    follow_redirect: true,
    force_redirect: true
  ]

  @spec options(keyword(), URI.t()) :: keyword()
  def options(connection_opts \\ [], %URI{} = uri) do
    proxy = Pleroma.Config.get([:http, :proxy_url])

    config_opts = Pleroma.Config.get([:http, :adapter], [])

    @defaults
    |> Keyword.merge(config_opts)
    |> Keyword.merge(connection_opts)
    |> add_scheme_opts(uri)
    |> maybe_add_with_body()
    |> Pleroma.HTTP.AdapterHelper.maybe_add_proxy(proxy)
  end

  defp add_scheme_opts(opts, %URI{scheme: "https"}) do
    Keyword.put(opts, :ssl_options, versions: [:"tlsv1.2", :"tlsv1.1", :tlsv1])
  end

  defp add_scheme_opts(opts, _), do: opts

  defp maybe_add_with_body(opts) do
    if opts[:max_body] do
      Keyword.put(opts, :with_body, true)
    else
      opts
    end
  end
end
