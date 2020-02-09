# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Endpoint do
  use Phoenix.Endpoint, otp_app: :pleroma

  socket("/socket", Pleroma.Web.UserSocket)

  plug(Pleroma.Plugs.SetLocalePlug)
  plug(CORSPlug)
  plug(Pleroma.Plugs.HTTPSecurityPlug)
  plug(Pleroma.Plugs.UploadedMedia)

  @static_cache_control "public max-age=86400 must-revalidate"

  # InstanceStatic needs to be before Plug.Static to be able to override shipped-static files
  # If you're adding new paths to `only:` you'll need to configure them in InstanceStatic as well
  # Cache-control headers are duplicated in case we turn off etags in the future
  plug(Pleroma.Plugs.InstanceStatic,
    at: "/",
    gzip: true,
    cache_control_for_etags: @static_cache_control,
    headers: %{
      "cache-control" => @static_cache_control
    }
  )

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phoenix.digest
  # when deploying your static files in production.
  plug(
    Plug.Static,
    at: "/",
    from: :pleroma,
    only:
      ~w(index.html robots.txt static finmoji emoji packs sounds images instance sw.js sw-pleroma.js favicon.png schemas doc),
    # credo:disable-for-previous-line Credo.Check.Readability.MaxLineLength
    gzip: true,
    cache_control_for_etags: @static_cache_control,
    headers: %{
      "cache-control" => @static_cache_control
    }
  )

  plug(Plug.Static.IndexHtml, at: "/pleroma/admin/")

  plug(Plug.Static,
    at: "/pleroma/admin/",
    from: {:pleroma, "priv/static/adminfe/"}
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug(Phoenix.CodeReloader)
  end

  plug(Pleroma.Plugs.TrailingFormatPlug)
  plug(Plug.RequestId)
  plug(Plug.Logger)

  plug(Plug.Parsers,
    parsers: [
      :urlencoded,
      {:multipart, length: {Pleroma.Config, :get, [[:instance, :upload_limit]]}},
      :json
    ],
    pass: ["*/*"],
    json_decoder: Jason,
    length: Pleroma.Config.get([:instance, :upload_limit]),
    body_reader: {Pleroma.Web.Plugs.DigestPlug, :read_body, []}
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  secure_cookies = Pleroma.Config.get([__MODULE__, :secure_cookie_flag])

  cookie_name =
    if secure_cookies,
      do: "__Host-pleroma_key",
      else: "pleroma_key"

  extra =
    Pleroma.Config.get([__MODULE__, :extra_cookie_attrs])
    |> Enum.join(";")

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug(
    Plug.Session,
    store: :cookie,
    key: cookie_name,
    signing_salt: Pleroma.Config.get([__MODULE__, :signing_salt], "CqaoopA2"),
    http_only: true,
    secure: secure_cookies,
    extra: extra
  )

  # Note: the plug and its configuration is compile-time this can't be upstreamed yet
  if proxies = Pleroma.Config.get([__MODULE__, :reverse_proxies]) do
    plug(RemoteIp, proxies: proxies)
  end

  defmodule Instrumenter do
    use Prometheus.PhoenixInstrumenter
  end

  defmodule PipelineInstrumenter do
    use Prometheus.PlugPipelineInstrumenter
  end

  defmodule MetricsExporter do
    use Prometheus.PlugExporter
  end

  plug(PipelineInstrumenter)
  plug(MetricsExporter)

  plug(Pleroma.Web.Router)

  @doc """
  Dynamically loads configuration from the system environment
  on startup.

  It receives the endpoint configuration from the config files
  and must return the updated configuration.
  """
  def load_from_system_env(config) do
    port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"
    {:ok, Keyword.put(config, :http, [:inet6, port: port])}
  end

  def websocket_url do
    String.replace_leading(url(), "http", "ws")
  end
end
