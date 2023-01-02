# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.SimplePolicy do
  @moduledoc "Filter activities depending on their origin instance"
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  alias Pleroma.Config
  alias Pleroma.FollowingRelationship
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.MRF

  require Pleroma.Constants

  defp check_accept(%{host: actor_host} = _actor_info, object) do
    accepts =
      instance_list(:accept)
      |> MRF.subdomains_regex()

    cond do
      accepts == [] -> {:ok, object}
      actor_host == Config.get([Pleroma.Web.Endpoint, :url, :host]) -> {:ok, object}
      MRF.subdomain_match?(accepts, actor_host) -> {:ok, object}
      true -> {:reject, "[SimplePolicy] host not in accept list"}
    end
  end

  defp check_reject(%{host: actor_host} = _actor_info, object) do
    rejects =
      instance_list(:reject)
      |> MRF.subdomains_regex()

    if MRF.subdomain_match?(rejects, actor_host) do
      {:reject, "[SimplePolicy] host in reject list"}
    else
      {:ok, object}
    end
  end

  defp check_media_removal(
         %{host: actor_host} = _actor_info,
         %{"type" => type, "object" => %{"attachment" => child_attachment}} = object
       )
       when length(child_attachment) > 0 and type in ["Create", "Update"] do
    media_removal =
      instance_list(:media_removal)
      |> MRF.subdomains_regex()

    object =
      if MRF.subdomain_match?(media_removal, actor_host) do
        child_object = Map.delete(object["object"], "attachment")
        Map.put(object, "object", child_object)
      else
        object
      end

    {:ok, object}
  end

  defp check_media_removal(_actor_info, object), do: {:ok, object}

  defp check_media_nsfw(
         %{host: actor_host} = _actor_info,
         %{
           "type" => type,
           "object" => %{} = _child_object
         } = object
       )
       when type in ["Create", "Update"] do
    media_nsfw =
      instance_list(:media_nsfw)
      |> MRF.subdomains_regex()

    object =
      if MRF.subdomain_match?(media_nsfw, actor_host) do
        Kernel.put_in(object, ["object", "sensitive"], true)
      else
        object
      end

    {:ok, object}
  end

  defp check_media_nsfw(_actor_info, object), do: {:ok, object}

  defp check_ftl_removal(%{host: actor_host} = _actor_info, object) do
    timeline_removal =
      instance_list(:federated_timeline_removal)
      |> MRF.subdomains_regex()

    object =
      with true <- MRF.subdomain_match?(timeline_removal, actor_host),
           user <- User.get_cached_by_ap_id(object["actor"]),
           true <- Pleroma.Constants.as_public() in object["to"] do
        to = List.delete(object["to"], Pleroma.Constants.as_public()) ++ [user.follower_address]

        cc = List.delete(object["cc"], user.follower_address) ++ [Pleroma.Constants.as_public()]

        object
        |> Map.put("to", to)
        |> Map.put("cc", cc)
      else
        _ -> object
      end

    {:ok, object}
  end

  defp intersection(list1, list2) do
    list1 -- list1 -- list2
  end

  defp check_followers_only(%{host: actor_host} = _actor_info, object) do
    followers_only =
      instance_list(:followers_only)
      |> MRF.subdomains_regex()

    object =
      with true <- MRF.subdomain_match?(followers_only, actor_host),
           user <- User.get_cached_by_ap_id(object["actor"]) do
        # Don't use Map.get/3 intentionally, these must not be nil
        fixed_to = object["to"] || []
        fixed_cc = object["cc"] || []

        to = FollowingRelationship.followers_ap_ids(user, fixed_to)
        cc = FollowingRelationship.followers_ap_ids(user, fixed_cc)

        object
        |> Map.put("to", intersection([user.follower_address | to], fixed_to))
        |> Map.put("cc", intersection([user.follower_address | cc], fixed_cc))
      else
        _ -> object
      end

    {:ok, object}
  end

  defp check_report_removal(%{host: actor_host} = _actor_info, %{"type" => "Flag"} = object) do
    report_removal =
      instance_list(:report_removal)
      |> MRF.subdomains_regex()

    if MRF.subdomain_match?(report_removal, actor_host) do
      {:reject, "[SimplePolicy] host in report_removal list"}
    else
      {:ok, object}
    end
  end

  defp check_report_removal(_actor_info, object), do: {:ok, object}

  defp check_avatar_removal(%{host: actor_host} = _actor_info, %{"icon" => _icon} = object) do
    avatar_removal =
      instance_list(:avatar_removal)
      |> MRF.subdomains_regex()

    if MRF.subdomain_match?(avatar_removal, actor_host) do
      {:ok, Map.delete(object, "icon")}
    else
      {:ok, object}
    end
  end

  defp check_avatar_removal(_actor_info, object), do: {:ok, object}

  defp check_banner_removal(%{host: actor_host} = _actor_info, %{"image" => _image} = object) do
    banner_removal =
      instance_list(:banner_removal)
      |> MRF.subdomains_regex()

    if MRF.subdomain_match?(banner_removal, actor_host) do
      {:ok, Map.delete(object, "image")}
    else
      {:ok, object}
    end
  end

  defp check_banner_removal(_actor_info, object), do: {:ok, object}

  defp check_object(%{"object" => object} = activity) do
    with {:ok, _object} <- filter(object) do
      {:ok, activity}
    end
  end

  defp check_object(object), do: {:ok, object}

  defp instance_list(config_key) do
    Config.get([:mrf_simple, config_key])
    |> MRF.instance_list_from_tuples()
  end

  @impl true
  def filter(%{"type" => "Delete", "actor" => actor} = object) do
    %{host: actor_host} = URI.parse(actor)

    reject_deletes =
      instance_list(:reject_deletes)
      |> MRF.subdomains_regex()

    if MRF.subdomain_match?(reject_deletes, actor_host) do
      {:reject, "[SimplePolicy] host in reject_deletes list"}
    else
      {:ok, object}
    end
  end

  @impl true
  def filter(%{"actor" => actor} = object) do
    actor_info = URI.parse(actor)

    with {:ok, object} <- check_accept(actor_info, object),
         {:ok, object} <- check_reject(actor_info, object),
         {:ok, object} <- check_media_removal(actor_info, object),
         {:ok, object} <- check_media_nsfw(actor_info, object),
         {:ok, object} <- check_ftl_removal(actor_info, object),
         {:ok, object} <- check_followers_only(actor_info, object),
         {:ok, object} <- check_report_removal(actor_info, object),
         {:ok, object} <- check_object(object) do
      {:ok, object}
    else
      {:reject, nil} -> {:reject, "[SimplePolicy]"}
      {:reject, _} = e -> e
      _ -> {:reject, "[SimplePolicy]"}
    end
  end

  def filter(%{"id" => actor, "type" => obj_type} = object)
      when obj_type in ["Application", "Group", "Organization", "Person", "Service"] do
    actor_info = URI.parse(actor)

    with {:ok, object} <- check_accept(actor_info, object),
         {:ok, object} <- check_reject(actor_info, object),
         {:ok, object} <- check_avatar_removal(actor_info, object),
         {:ok, object} <- check_banner_removal(actor_info, object) do
      {:ok, object}
    else
      {:reject, nil} -> {:reject, "[SimplePolicy]"}
      {:reject, _} = e -> e
      _ -> {:reject, "[SimplePolicy]"}
    end
  end

  def filter(object) when is_binary(object) do
    uri = URI.parse(object)

    with {:ok, object} <- check_accept(uri, object),
         {:ok, object} <- check_reject(uri, object) do
      {:ok, object}
    else
      {:reject, nil} -> {:reject, "[SimplePolicy]"}
      {:reject, _} = e -> e
      _ -> {:reject, "[SimplePolicy]"}
    end
  end

  def filter(object), do: {:ok, object}

  @impl true
  def describe do
    exclusions = Config.get([:mrf, :transparency_exclusions]) |> MRF.instance_list_from_tuples()

    mrf_simple_excluded =
      Config.get(:mrf_simple)
      |> Enum.map(fn {rule, instances} ->
        {rule, Enum.reject(instances, fn {host, _} -> host in exclusions end)}
      end)

    mrf_simple =
      mrf_simple_excluded
      |> Enum.map(fn {rule, instances} ->
        {rule, Enum.map(instances, fn {host, _} -> host end)}
      end)
      |> Map.new()

    # This is for backwards compatibility. We originally didn't sent
    # extra info like a reason why an instance was rejected/quarantined/etc.
    # Because we didn't want to break backwards compatibility it was decided
    # to add an extra "info" key.
    mrf_simple_info =
      mrf_simple_excluded
      |> Enum.map(fn {rule, instances} ->
        {rule, Enum.reject(instances, fn {_, reason} -> reason == "" end)}
      end)
      |> Enum.reject(fn {_, instances} -> instances == [] end)
      |> Enum.map(fn {rule, instances} ->
        instances =
          instances
          |> Enum.map(fn {host, reason} -> {host, %{"reason" => reason}} end)
          |> Map.new()

        {rule, instances}
      end)
      |> Map.new()

    {:ok, %{mrf_simple: mrf_simple, mrf_simple_info: mrf_simple_info}}
  end

  @impl true
  def config_description do
    %{
      key: :mrf_simple,
      related_policy: "Pleroma.Web.ActivityPub.MRF.SimplePolicy",
      label: "MRF Simple",
      description: "Simple ingress policies",
      children:
        [
          %{
            key: :media_removal,
            description:
              "List of instances to strip media attachments from and the reason for doing so"
          },
          %{
            key: :media_nsfw,
            label: "Media NSFW",
            description:
              "List of instances to tag all media as NSFW (sensitive) from and the reason for doing so"
          },
          %{
            key: :federated_timeline_removal,
            description:
              "List of instances to remove from the Federated (aka The Whole Known Network) Timeline and the reason for doing so"
          },
          %{
            key: :reject,
            description:
              "List of instances to reject activities from (except deletes) and the reason for doing so"
          },
          %{
            key: :accept,
            description:
              "List of instances to only accept activities from (except deletes) and the reason for doing so"
          },
          %{
            key: :followers_only,
            description:
              "Force posts from the given instances to be visible by followers only and the reason for doing so"
          },
          %{
            key: :report_removal,
            description: "List of instances to reject reports from and the reason for doing so"
          },
          %{
            key: :avatar_removal,
            description: "List of instances to strip avatars from and the reason for doing so"
          },
          %{
            key: :banner_removal,
            description: "List of instances to strip banners from and the reason for doing so"
          },
          %{
            key: :reject_deletes,
            description: "List of instances to reject deletions from and the reason for doing so"
          }
        ]
        |> Enum.map(fn setting ->
          Map.merge(
            setting,
            %{
              type: {:list, :tuple},
              key_placeholder: "instance",
              value_placeholder: "reason",
              suggestions: [{"example.com", "Some reason"}, {"*.example.com", "Another reason"}]
            }
          )
        end)
    }
  end
end
