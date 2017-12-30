
defmodule Pleroma.HTTP do
  use HTTPoison.Base

  def process_request_options(options) do
    config = Application.get_env(:pleroma, :http, [])
    proxy = Keyword.get(config, :proxy_url, "")
    case proxy do
      "" -> options
      _ -> options ++ [proxy: proxy]
    end
  end

end
