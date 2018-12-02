defmodule Pleroma.HTTP.Connection do
  @hackney_options [pool: :default]
  @adapter Application.get_env(:tesla, :adapter)

  @doc """
  Configure a client connection

  # Returns

  Tesla.Env.client
  """
  @spec new(Keyword.t()) :: Tesla.Env.client()
  def new(opts \\ []) do
    Tesla.client([], {@adapter, hackney_options(opts)})
  end

  # fetch Hackney options
  #
  defp hackney_options(opts \\ []) do
    options = Keyword.get(opts, :adapter, [])
    @hackney_options ++ options
  end
end
