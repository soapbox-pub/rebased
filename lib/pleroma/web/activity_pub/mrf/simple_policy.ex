# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.SimplePolicy do
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.MRF
  @moduledoc "Filter activities depending on their origin instance"
  @behaviour Pleroma.Web.ActivityPub.MRF

  require Pleroma.Constants

  defp check_accept(%{host: actor_host} = _actor_info, object) do
    accepts =
      Pleroma.Config.get([:mrf_simple, :accept])
      |> MRF.subdomains_regex()

    cond do
      accepts == [] -> {:ok, object}
      actor_host == Pleroma.Config.get([Pleroma.Web.Endpoint, :url, :host]) -> {:ok, object}
      MRF.subdomain_match?(accepts, actor_host) -> {:ok, object}
      true -> {:reject, nil}
    end
  end

  defp check_reject(%{host: actor_host} = _actor_info, object) do
    rejects =
      Pleroma.Config.get([:mrf_simple, :reject])
      |> MRF.subdomains_regex()

    if MRF.subdomain_match?(rejects, actor_host) do
      {:reject, nil}
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
      Pleroma.Config.get([:mrf_simple, :media_removal])
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
       ) do
    media_nsfw =
      Pleroma.Config.get([:mrf_simple, :media_nsfw])
      |> MRF.subdomains_regex()

    object =
      if MRF.subdomain_match?(media_nsfw, actor_host) do
        tags = (child_object["tag"] || []) ++ ["nsfw"]
        child_object = Map.put(child_object, "tag", tags)
        child_object = Map.put(child_object, "sensitive", true)
        Map.put(object, "object", child_object)
      else
        object
      end

    {:ok, object}
  end

  defp check_media_nsfw(_actor_info, object), do: {:ok, object}

  defp check_ftl_removal(%{host: actor_host} = _actor_info, object) do
    timeline_removal =
      Pleroma.Config.get([:mrf_simple, :federated_timeline_removal])
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

  defp check_report_removal(%{host: actor_host} = _actor_info, %{"type" => "Flag"} = object) do
    report_removal =
      Pleroma.Config.get([:mrf_simple, :report_removal])
      |> MRF.subdomains_regex()

    if MRF.subdomain_match?(report_removal, actor_host) do
      {:reject, nil}
    else
      {:ok, object}
    end
  end

  defp check_report_removal(_actor_info, object), do: {:ok, object}

  defp check_avatar_removal(%{host: actor_host} = _actor_info, %{"icon" => _icon} = object) do
    avatar_removal =
      Pleroma.Config.get([:mrf_simple, :avatar_removal])
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
      Pleroma.Config.get([:mrf_simple, :banner_removal])
      |> MRF.subdomains_regex()

    if MRF.subdomain_match?(banner_removal, actor_host) do
      {:ok, Map.delete(object, "image")}
    else
      {:ok, object}
    end
  end

  defp check_banner_removal(_actor_info, object), do: {:ok, object}

  @impl true
  def filter(%{"actor" => actor} = object) do
    actor_info = URI.parse(actor)

    with {:ok, object} <- check_accept(actor_info, object),
         {:ok, object} <- check_reject(actor_info, object),
         {:ok, object} <- check_media_removal(actor_info, object),
         {:ok, object} <- check_media_nsfw(actor_info, object),
         {:ok, object} <- check_ftl_removal(actor_info, object),
         {:ok, object} <- check_report_removal(actor_info, object) do
      {:ok, object}
    else
      _e -> {:reject, nil}
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
      _e -> {:reject, nil}
    end
  end

  def filter(object), do: {:ok, object}

  @impl true
  def describe do
    exclusions = Pleroma.Config.get([:instance, :mrf_transparency_exclusions])

    mrf_simple =
      Pleroma.Config.get(:mrf_simple)
      |> Enum.map(fn {k, v} -> {k, Enum.reject(v, fn v -> v in exclusions end)} end)
      |> Enum.into(%{})

    {:ok, %{mrf_simple: mrf_simple}}
  end
end
