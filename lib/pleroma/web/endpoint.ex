defmodule Pleroma.Web.Endpoint do
  use Phoenix.Endpoint, otp_app: :pleroma

  socket("/socket", Pleroma.Web.UserSocket)

  socket("/api/v1", Pleroma.Web.MastodonAPI.MastodonSocket, websocket: [path: "/streaming"])

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phoenix.digest
  # when deploying your static files in production.
  plug(CORSPlug)
  plug(Pleroma.Plugs.HTTPSecurityPlug)

  plug(Pleroma.Plugs.UploadedMedia)

  plug(
    Plug.Static,
    at: "/",
    from: :pleroma,
    only:
      ~w(index.html static finmoji emoji packs sounds images instance sw.js favicon.png schemas)
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug(Phoenix.CodeReloader)
  end

  plug(TrailingFormatPlug)
  plug(Plug.RequestId)
  plug(Plug.Logger)

  plug(
    Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason,
    length: Application.get_env(:pleroma, :instance) |> Keyword.get(:upload_limit),
    body_reader: {Pleroma.Web.Plugs.DigestPlug, :read_body, []}
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  cookie_name =
    if Application.get_env(:pleroma, Pleroma.Web.Endpoint) |> Keyword.get(:secure_cookie_flag),
      do: "__Host-pleroma_key",
      else: "pleroma_key"

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug(
    Plug.Session,
    store: :cookie,
    key: cookie_name,
    signing_salt: {Pleroma.Config, :get, [[__MODULE__, :signing_salt], "CqaoopA2"]},
    http_only: true,
    secure:
      Application.get_env(:pleroma, Pleroma.Web.Endpoint) |> Keyword.get(:secure_cookie_flag),
    extra: "SameSite=Strict"
  )

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
end
