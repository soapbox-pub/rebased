defmodule Pleroma.Web.MediaProxy.Invalidation do
  @callback purge(list(String.t()), map()) :: {:ok, String.t()} | {:error, String.t()}

  alias Pleroma.Config

  def purge(urls) do
    [:media_proxy, :invalidation, :enabled]
    |> Config.get()
    |> do_purge(urls)
  end

  defp do_purge(true, urls) do
    config = Config.get([:media_proxy, :invalidation])
    config[:provider].purge(urls, config[:options])
    :ok
  end

  defp do_purge(_, _), do: :ok
end
