# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.SimplePolicy do
  @moduledoc "Filter activities depending on their origin instance"
  @behaviour Pleroma.Web.ActivityPub.MRF

  alias Pleroma.Config
  alias Pleroma.FollowingRelationship
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.MRF

  require Pleroma.Constants

  defp check_accept(%{host: actor_host} = _actor_info, object) do
    accepts =
      Config.get([:mrf_simple, :accept])
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
      Config.get([:mrf_simple, :reject])
      |> MRF.subdomains_regex()

    if MRF.subdomain_match?(rejects, actor_host) do
      {:reject, "[SimplePolicy] host in reject list"}
    else
      {:ok, object}
    end
  end

  defp check_media_removal(
         %{host: actor_host} = _actor_info,
         %{"type" => "Create", "object" => %{"attachment" => child_attachment}} = object
       )
       when length(child_attachment) > 0 do
    media_removal =
      Config.get([:mrf_simple, :media_removal])
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
           "type" => "Create",
           "object" => child_object
         } = object
       )
       when is_map(child_object) do
    media_nsfw =
      Config.get([:mrf_simple, :media_nsfw])
      |> MRF.subdomains_regex()

    object =
      if MRF.subdomain_match?(media_nsfw, actor_host) do
        child_object =
          child_object
          |> Map.put("hashtags", (child_object["hashtags"] || []) ++ ["nsfw"])
          |> Map.put("sensitive", true)

        Map.put(object, "object", child_object)
      else
        object
      end

    {:ok, object}
  end

  defp check_media_nsfw(_actor_info, object), do: {:ok, object}

  defp check_ftl_removal(%{host: actor_host} = _actor_info, object) do
    timeline_removal =
      Config.get([:mrf_simple, :federated_timeline_removal])
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
      Config.get([:mrf_simple, :followers_only])
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
      Config.get([:mrf_simple, :report_removal])
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
      Config.get([:mrf_simple, :avatar_removal])
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
      Config.get([:mrf_simple, :banner_removal])
      |> MRF.subdomains_regex()

    if MRF.subdomain_match?(banner_removal, actor_host) do
      {:ok, Map.delete(object, "image")}
    else
      {:ok, object}
    end
  end

  defp check_banner_removal(_actor_info, object), do: {:ok, object}

  @impl true
  def filter(%{"type" => "Delete", "actor" => actor} = object) do
    %{host: actor_host} = URI.parse(actor)

    reject_deletes =
      Config.get([:mrf_simple, :reject_deletes])
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
         {:ok, object} <- check_report_removal(actor_info, object) do
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

  def filter(object), do: {:ok, object}

  @impl true
  def describe do
    exclusions = Config.get([:mrf, :transparency_exclusions])

    mrf_simple =
      Config.get(:mrf_simple)
      |> Enum.map(fn {k, v} -> {k, Enum.reject(v, fn v -> v in exclusions end)} end)
      |> Enum.into(%{})

    {:ok, %{mrf_simple: mrf_simple}}
  end

  @impl true
  def config_description do
    %{
      key: :mrf_simple,
      related_policy: "Pleroma.Web.ActivityPub.MRF.SimplePolicy",
      label: "MRF Simple",
      description: "Simple ingress policies",
      children: [
        %{
          key: :media_removal,
          type: {:list, :string},
          description: "List of instances to strip media attachments from",
          suggestions: ["example.com", "*.example.com"]
        },
        %{
          key: :media_nsfw,
          label: "Media NSFW",
          type: {:list, :string},
          description: "List of instances to tag all media as NSFW (sensitive) from",
          suggestions: ["example.com", "*.example.com"]
        },
        %{
          key: :federated_timeline_removal,
          type: {:list, :string},
          description:
            "List of instances to remove from the Federated (aka The Whole Known Network) Timeline",
          suggestions: ["example.com", "*.example.com"]
        },
        %{
          key: :reject,
          type: {:list, :string},
          description: "List of instances to reject activities from (except deletes)",
          suggestions: ["example.com", "*.example.com"]
        },
        %{
          key: :accept,
          type: {:list, :string},
          description: "List of instances to only accept activities from (except deletes)",
          suggestions: ["example.com", "*.example.com"]
        },
        %{
          key: :followers_only,
          type: {:list, :string},
          description: "Force posts from the given instances to be visible by followers only",
          suggestions: ["example.com", "*.example.com"]
        },
        %{
          key: :report_removal,
          type: {:list, :string},
          description: "List of instances to reject reports from",
          suggestions: ["example.com", "*.example.com"]
        },
        %{
          key: :avatar_removal,
          type: {:list, :string},
          description: "List of instances to strip avatars from",
          suggestions: ["example.com", "*.example.com"]
        },
        %{
          key: :banner_removal,
          type: {:list, :string},
          description: "List of instances to strip banners from",
          suggestions: ["example.com", "*.example.com"]
        },
        %{
          key: :reject_deletes,
          type: {:list, :string},
          description: "List of instances to reject deletions from",
          suggestions: ["example.com", "*.example.com"]
        }
      ]
    }
  end
end
