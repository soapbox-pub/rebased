defmodule Pleroma.HTTP do
  require HTTPoison

  def request(method, url, body \\ "", headers \\ [], options \\ []) do
    options =
      process_request_options(options)
      |> process_sni_options(url)

    HTTPoison.request(method, url, body, headers, options)
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

    case proxy do
      nil -> options
      _ -> options ++ [proxy: proxy]
    end
  end

  def get(url, headers \\ [], options \\ []), do: request(:get, url, "", headers, options)

  def post(url, body, headers \\ [], options \\ []),
    do: request(:post, url, body, headers, options)
end
