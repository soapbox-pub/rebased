defmodule Pleroma.HTTP do
  require HTTPoison
  alias Pleroma.HTTP.Connection
  alias Pleroma.HTTP.RequestBuilder, as: Builder

  def request(method, url, body \\ "", headers \\ [], options \\ []) do
    options =
      process_request_options(options)
      |> process_sni_options(url)

    %{}
    |> Builder.method(method)
    |> Builder.headers(headers)
    |> Builder.opts(options)
    |> Builder.url(url)
    |> Builder.add_param(:body, :body, body)
    |> Enum.into([])
    |> (&Tesla.request(Connection.new(), &1)).()
  end

  defp process_sni_options(options, url) do
    uri = URI.parse(url)
    host = uri.host |> to_charlist()

    case uri.scheme do
      "https" -> options ++ [ssl: [server_name_indication: host]]
      _ -> options
    end
  end

  def process_request_options(options) do
    config = Application.get_env(:pleroma, :http, [])
    proxy = Keyword.get(config, :proxy_url, nil)
    options = options ++ [adapter: [pool: :default]]

    case proxy do
      nil -> options
      _ -> options ++ [proxy: proxy]
    end
  end

  def get(url, headers \\ [], options \\ []),
    do: request(:get, url, "", headers, options)

  def post(url, body, headers \\ [], options \\ []),
    do: request(:post, url, body, headers, options)
end
