defmodule Pleroma.Captcha do
  use GenServer

  @ets_options [:ordered_set, :private, :named_table, {:read_concurrency, true}]

  @doc false
  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc false
  def init(_) do
    # Create a ETS table to store captchas
    ets_name = Module.concat(method(), Ets)
    ^ets_name = :ets.new(Module.concat(method(), Ets), @ets_options)

    {:ok, nil}
  end

  @doc """
  Ask the configured captcha service for a new captcha
  """
  def new() do
    GenServer.call(__MODULE__, :new)
  end

  @doc """
  Ask the configured captcha service to validate the captcha
  """
  def validate(token, captcha) do
    GenServer.call(__MODULE__, {:validate, token, captcha})
  end

  @doc false
  def handle_call(:new, _from, state) do
    enabled = Pleroma.Config.get([__MODULE__, :enabled])

    if !enabled do
      {:reply, %{type: :none}, state}
    else
      {:reply, method().new(), state}
    end
  end

  @doc false
  def handle_call({:validate, token, captcha}, _from, state) do
    {:reply, method().validate(token, captcha), state}
  end

  defp method, do: Pleroma.Config.get!([__MODULE__, :method])
end
