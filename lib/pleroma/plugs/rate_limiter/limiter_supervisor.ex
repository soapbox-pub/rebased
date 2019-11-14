defmodule Pleroma.Plugs.RateLimiter.LimiterSupervisor do
  use DynamicSupervisor

  import Cachex.Spec

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def add_limiter(limiter_name, expiration) do
    {:ok, _pid} =
      DynamicSupervisor.start_child(
        __MODULE__,
        %{
          id: String.to_atom("rl_#{limiter_name}"),
          start:
            {Cachex, :start_link,
             [
               limiter_name,
               [
                 expiration:
                   expiration(
                     default: expiration,
                     interval: check_interval(expiration),
                     lazy: true
                   )
               ]
             ]}
        }
      )
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defp check_interval(exp) do
    (exp / 2)
    |> Kernel.trunc()
    |> Kernel.min(5000)
    |> Kernel.max(1)
  end
end
