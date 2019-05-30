# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF do
  @callback filter(Map.t()) :: {:ok | :reject, Map.t()}

  def filter(object) do
    get_policies()
    |> Enum.reduce({:ok, object}, fn
      policy, {:ok, object} ->
        policy.filter(object)

      _, error ->
        error
    end)
  end

  def get_policies do
    Pleroma.Config.get([:instance, :rewrite_policy], []) |> get_policies()
  end

  defp get_policies(policy) when is_atom(policy), do: [policy]
  defp get_policies(policies) when is_list(policies), do: policies
  defp get_policies(_), do: []
end
