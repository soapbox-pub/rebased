# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.SimplePolicy do
  alias Pleroma.User
  @moduledoc "Filter activities depending on their origin instance"
  @behaviour Pleroma.Web.ActivityPub.MRF

  defp check_accept(%{host: actor_host} = _actor_info, object) do
    accepts = Pleroma.Config.get([:mrf_simple, :accept])

    cond do
      accepts == [] -> {:ok, object}
      actor_host == Pleroma.Config.get([Pleroma.Web.Endpoint, :url, :host]) -> {:ok, object}
      Enum.member?(accepts, actor_host) -> {:ok, object}
      true -> {:reject, nil}
    end
  end

  defp check_reject(%{host: actor_host} = _actor_info, object) do
    if Enum.member?(Pleroma.Config.get([:mrf_simple, :reject]), actor_host) do
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
    object =
      if Enum.member?(Pleroma.Config.get([:mrf_simple, :media_removal]), actor_host) do
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
    object =
      if Enum.member?(Pleroma.Config.get([:mrf_simple, :media_nsfw]), actor_host) do
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
    object =
      with true <-
             Enum.member?(
               Pleroma.Config.get([:mrf_simple, :federated_timeline_removal]),
               actor_host
             ),
           user <- User.get_cached_by_ap_id(object["actor"]),
           true <- "https://www.w3.org/ns/activitystreams#Public" in object["to"] do
        to =
          List.delete(object["to"], "https://www.w3.org/ns/activitystreams#Public") ++
            [user.follower_address]

        cc =
          List.delete(object["cc"], user.follower_address) ++
            ["https://www.w3.org/ns/activitystreams#Public"]

        object
        |> Map.put("to", to)
        |> Map.put("cc", cc)
      else
        _ -> object
      end

    {:ok, object}
  end

  defp check_report_removal(%{host: actor_host} = _actor_info, %{"type" => "Flag"} = object) do
    if actor_host in Pleroma.Config.get([:mrf_simple, :report_removal]) do
      {:reject, nil}
    else
      {:ok, object}
    end
  end

  defp check_report_removal(_actor_info, object), do: {:ok, object}

  defp check_avatar_removal(%{host: actor_host} = _actor_info, %{"icon" => _icon} = object) do
    if actor_host in Pleroma.Config.get([:mrf_simple, :avatar_removal]) do
      {:ok, Map.delete(object, "icon")}
    else
      {:ok, object}
    end
  end

  defp check_avatar_removal(_actor_info, object), do: {:ok, object}

  defp check_banner_removal(%{host: actor_host} = _actor_info, %{"image" => _image} = object) do
    if actor_host in Pleroma.Config.get([:mrf_simple, :banner_removal]) do
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

    with {:ok, object} <- check_avatar_removal(actor_info, object),
         {:ok, object} <- check_banner_removal(actor_info, object) do
      {:ok, object}
    else
      _e -> {:reject, nil}
    end
  end

  def filter(object), do: {:ok, object}
end
