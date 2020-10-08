# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF do
  @callback filter(Map.t()) :: {:ok | :reject, Map.t()}

  def filter(policies, %{} = message) do
    policies
    |> Enum.reduce({:ok, message}, fn
      policy, {:ok, message} -> policy.filter(message)
      _, error -> error
    end)
  end

  def filter(%{} = object), do: get_policies() |> filter(object)

  def pipeline_filter(%{} = message, meta) do
    object = meta[:object_data]
    ap_id = message["object"]

    if object && ap_id do
      with {:ok, message} <- filter(Map.put(message, "object", object)) do
        meta = Keyword.put(meta, :object_data, message["object"])
        {:ok, Map.put(message, "object", ap_id), meta}
      else
        {err, message} -> {err, message, meta}
      end
    else
      {err, message} = filter(message)

      {err, message, meta}
    end
  end

  def get_policies do
    Pleroma.Config.get([:mrf, :policies], []) |> get_policies()
  end

  defp get_policies(policy) when is_atom(policy), do: [policy]
  defp get_policies(policies) when is_list(policies), do: policies
  defp get_policies(_), do: []

  @spec subdomains_regex([String.t()]) :: [Regex.t()]
  def subdomains_regex(domains) when is_list(domains) do
    for domain <- domains, do: ~r(^#{String.replace(domain, "*.", "(.*\\.)*")}$)i
  end

  @spec subdomain_match?([Regex.t()], String.t()) :: boolean()
  def subdomain_match?(domains, host) do
    Enum.any?(domains, fn domain -> Regex.match?(domain, host) end)
  end

  @callback describe() :: {:ok | :error, Map.t()}

  def describe(policies) do
    {:ok, policy_configs} =
      policies
      |> Enum.reduce({:ok, %{}}, fn
        policy, {:ok, data} ->
          {:ok, policy_data} = policy.describe()
          {:ok, Map.merge(data, policy_data)}

        _, error ->
          error
      end)

    mrf_policies =
      get_policies()
      |> Enum.map(fn policy -> to_string(policy) |> String.split(".") |> List.last() end)

    exclusions = Pleroma.Config.get([:mrf, :transparency_exclusions])

    base =
      %{
        mrf_policies: mrf_policies,
        exclusions: length(exclusions) > 0
      }
      |> Map.merge(policy_configs)

    {:ok, base}
  end

  def describe, do: get_policies() |> describe()
end
