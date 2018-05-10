defmodule Pleroma.Web.ActivityPub.MRF do

  @callback filter(Map.t) :: {:ok | :reject, Map.t}

  def filter(object) do
    get_policies()
    |> Enum.reduce({:ok, object}, fn
      (policy, {:ok, object}) ->
        policy.filter(object)
      (_, error) -> error
    end)
  end

  def get_policies() do
    Application.get_env(:pleroma, :instance, [])
    |> Keyword.get(:rewrite_policy, [])
    |> get_policies()
  end
  def get_policies(policy) when is_atom(policy), do: [policy]
  def get_policies(policies) when is_list(policies), do: policies
end
