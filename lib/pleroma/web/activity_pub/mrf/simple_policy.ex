defmodule Pleroma.Web.ActivityPub.MRF.SimplePolicy do
  alias Pleroma.User
  @behaviour Pleroma.Web.ActivityPub.MRF

  @mrf_policy Application.get_env(:pleroma, :mrf_simple)

  @accept Keyword.get(@mrf_policy, :accept)
  defp check_accept(%{host: actor_host} = actor_info, object)
       when length(@accept) > 0 and not (actor_host in @accept) do
    {:reject, nil}
  end

  defp check_accept(actor_info, object), do: {:ok, object}

  @reject Keyword.get(@mrf_policy, :reject)
  defp check_reject(%{host: actor_host} = actor_info, object) when actor_host in @reject do
    {:reject, nil}
  end

  defp check_reject(actor_info, object), do: {:ok, object}

  @media_removal Keyword.get(@mrf_policy, :media_removal)
  defp check_media_removal(%{host: actor_host} = actor_info, %{"type" => "Create"} = object)
       when actor_host in @media_removal do
    child_object = Map.delete(object["object"], "attachment")
    object = Map.put(object, "object", child_object)
    {:ok, object}
  end

  defp check_media_removal(actor_info, object), do: {:ok, object}

  @media_nsfw Keyword.get(@mrf_policy, :media_nsfw)
  defp check_media_nsfw(
         %{host: actor_host} = actor_info,
         %{
           "type" => "Create",
           "object" => %{"attachment" => child_attachment} = child_object
         } = object
       )
       when actor_host in @media_nsfw and length(child_attachment) > 0 do
    tags = (child_object["tag"] || []) ++ ["nsfw"]
    child_object = Map.put(child_object, "tags", tags)
    child_object = Map.put(child_object, "sensitive", true)
    object = Map.put(object, "object", child_object)
    {:ok, object}
  end

  defp check_media_nsfw(actor_info, object), do: {:ok, object}

  @ftl_removal Keyword.get(@mrf_policy, :federated_timeline_removal)
  defp check_ftl_removal(%{host: actor_host} = actor_info, object)
       when actor_host in @ftl_removal do
    user = User.get_by_ap_id(object["actor"])

    # flip to/cc relationship to make the post unlisted
    object =
      if "https://www.w3.org/ns/activitystreams#Public" in object["to"] and
           user.follower_address in object["cc"] do
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
        object
      end

    {:ok, object}
  end

  defp check_ftl_removal(actor_info, object), do: {:ok, object}

  @impl true
  def filter(object) do
    actor_info = URI.parse(object["actor"])

    with {:ok, object} <- check_accept(actor_info, object),
         {:ok, object} <- check_reject(actor_info, object),
         {:ok, object} <- check_media_removal(actor_info, object),
         {:ok, object} <- check_media_nsfw(actor_info, object),
         {:ok, object} <- check_ftl_removal(actor_info, object) do
      {:ok, object}
    else
      _e -> {:reject, nil}
    end
  end
end
