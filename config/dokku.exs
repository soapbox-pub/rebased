use Mix.Config

config :pleroma, Pleroma.Web.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    protocol_options: [max_request_line_length: 8192, max_header_value_length: 8192]
  ],
  protocol: "http",
  secure_cookie_flag: false,
  url: [host: System.get_env("APP_HOST"), scheme: "https", port: 443],
  secret_key_base: "+S+ULgf7+N37c/lc9K66SMphnjQIRGklTu0BRr2vLm2ZzvK0Z6OH/PE77wlUNtvP"

database_url =
  System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

config :pleroma, Pleroma.Repo,
  # ssl: true,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :pleroma, :instance, name: "#{System.get_env("APP_NAME")} CI Instance"
