defmodule Pleroma.Web.MediaProxy.Invalidation.Nginx do
  @behaviour Pleroma.Web.MediaProxy.Invalidation

  @impl Pleroma.Web.MediaProxy.Invalidation
  def purge(urls, _opts) do
    Enum.each(urls, fn url ->
      Pleroma.HTTP.request(:purge, url, "", [], [])
    end)

    {:ok, "success"}
  end
end
