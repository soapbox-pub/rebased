# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF do
  require Logger
  import Pleroma.Web.Utils.Guards, only: [not_empty_string: 1]

  @behaviour Pleroma.Web.ActivityPub.MRF.PipelineFiltering

  @mrf_config_descriptions [
    %{
      group: :pleroma,
      key: :mrf,
      tab: :mrf,
      label: "MRF",
      type: :group,
      description: "General MRF settings",
      children: [
        %{
          key: :policies,
          type: [:module, {:list, :module}],
          description:
            "A list of MRF policies enabled. Module names are shortened (removed leading `Pleroma.Web.ActivityPub.MRF.` part), but on adding custom module you need to use full name.",
          suggestions: {:list_behaviour_implementations, Pleroma.Web.ActivityPub.MRF.Policy}
        },
        %{
          key: :transparency,
          label: "MRF transparency",
          type: :boolean,
          description:
            "Make the content of your Message Rewrite Facility settings public (via nodeinfo)"
        },
        %{
          key: :transparency_exclusions,
          label: "MRF transparency exclusions",
          type: {:list, :tuple},
          key_placeholder: "instance",
          value_placeholder: "reason",
          description:
            "Exclude specific instance names from MRF transparency. The use of the exclusions feature will be disclosed in nodeinfo as a boolean value. You can also provide a reason for excluding these instance names. The instances and reasons won't be publicly disclosed.",
          suggestions: [
            "exclusion.com"
          ]
        }
      ]
    }
  ]

  @default_description %{
    label: "",
    description: ""
  }

  @required_description_keys [:key, :related_policy]

  def filter(policies, %{} = message) do
    policies
    |> Enum.reduce({:ok, message}, fn
      policy, {:ok, message} -> policy.filter(message)
      _, error -> error
    end)
  end

  def filter(%{} = object), do: get_policies() |> filter(object)

  @impl true
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
    Pleroma.Config.get([:mrf, :policies], [])
    |> get_policies()
    |> Enum.concat([Pleroma.Web.ActivityPub.MRF.HashtagPolicy])
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

  @spec instance_list_from_tuples([{String.t(), String.t()}]) :: [String.t()]
  def instance_list_from_tuples(list) do
    Enum.map(list, fn
      {instance, _} -> instance
      instance when is_binary(instance) -> instance
    end)
  end

  @spec normalize_instance_list(list()) :: [{String.t(), String.t()}]
  def normalize_instance_list(list) do
    Enum.map(list, fn
      {host, reason} when not_empty_string(host) and not_empty_string(reason) -> {host, reason}
      {host, _reason} when not_empty_string(host) -> {host, ""}
      host when not_empty_string(host) -> {host, ""}
      value -> raise "Invalid MRF config: #{inspect(value)}"
    end)
  end

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

  def config_descriptions do
    Pleroma.Web.ActivityPub.MRF.Policy
    |> Pleroma.Docs.Generator.list_behaviour_implementations()
    |> config_descriptions()
  end

  def config_descriptions(policies) do
    Enum.reduce(policies, @mrf_config_descriptions, fn policy, acc ->
      if function_exported?(policy, :config_description, 0) do
        description =
          @default_description
          |> Map.merge(policy.config_description)
          |> Map.put(:group, :pleroma)
          |> Map.put(:tab, :mrf)
          |> Map.put(:type, :group)

        if Enum.all?(@required_description_keys, &Map.has_key?(description, &1)) do
          [description | acc]
        else
          Logger.warn(
            "#{policy} config description doesn't have one or all required keys #{inspect(@required_description_keys)}"
          )

          acc
        end
      else
        Logger.debug(
          "#{policy} is excluded from config descriptions, because does not implement `config_description/0` method."
        )

        acc
      end
    end)
  end
end
