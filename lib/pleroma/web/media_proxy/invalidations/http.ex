defmodule Pleroma.Web.MediaProxy.Invalidation.Http do
  @behaviour Pleroma.Web.MediaProxy.Invalidation

  @impl Pleroma.Web.MediaProxy.Invalidation
  def purge(urls, opts) do
    method = Map.get(opts, :method, :purge)
    headers = Map.get(opts, :headers, [])
    options = Map.get(opts, :options, [])

    Enum.each(urls, fn url ->
      Pleroma.HTTP.request(method, url, "", headers, options)
    end)

    {:ok, "success"}
  end
end
