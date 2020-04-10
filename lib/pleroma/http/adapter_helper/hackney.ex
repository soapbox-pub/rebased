defmodule Pleroma.HTTP.AdapterHelper.Hackney do
  @behaviour Pleroma.HTTP.AdapterHelper

  @defaults [
    connect_timeout: 10_000,
    recv_timeout: 20_000,
    follow_redirect: true,
    force_redirect: true,
    pool: :federation
  ]

  @spec options(keyword(), URI.t()) :: keyword()
  def options(connection_opts \\ [], %URI{} = uri) do
    proxy = Pleroma.Config.get([:http, :proxy_url])

    config_opts = Pleroma.Config.get([:http, :adapter], [])

    @defaults
    |> Keyword.merge(config_opts)
    |> Keyword.merge(connection_opts)
    |> add_scheme_opts(uri)
    |> Pleroma.HTTP.AdapterHelper.maybe_add_proxy(proxy)
  end

  defp add_scheme_opts(opts, %URI{scheme: "http"}), do: opts

  defp add_scheme_opts(opts, %URI{scheme: "https", host: host}) do
    ssl_opts = [
      ssl_options: [
        # Workaround for remote server certificate chain issues
        partial_chain: &:hackney_connect.partial_chain/1,

        # We don't support TLS v1.3 yet
        versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"],
        server_name_indication: to_charlist(host)
      ]
    ]

    Keyword.merge(opts, ssl_opts)
  end

  def after_request(_), do: :ok
end
