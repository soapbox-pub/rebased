defmodule Pleroma.Web.ActivityPub.MRF.SimplePolicy do
  alias Pleroma.User

  @mrf_policy Application.get_env(:pleroma, :mrf_simple)

  @reject Keyword.get(@mrf_policy, :reject)
  defp check_reject(actor_info, object) do
    if actor_info.host in @reject do
      {:reject, nil}
    else
      {:ok, object}
    end
  end

  @media_removal Keyword.get(@mrf_policy, :media_removal)
  defp check_media_removal(actor_info, object) do
    if actor_info.host in @media_removal do
      child_object = Map.delete(object["object"], "attachment")
      object = Map.put(object, "object", child_object)
    end

    {:ok, object}
  end

  @media_nsfw Keyword.get(@mrf_policy, :media_nsfw)
  defp check_media_nsfw(actor_info, object) do
    child_object = object["object"]

    if actor_info.host in @media_nsfw and child_object["attachment"] != nil and
         length(child_object["attachment"]) > 0 do
      tags = (child_object["tag"] || []) ++ ["nsfw"]
      child_object = Map.put(child_object, "tags", tags)
      child_object = Map.put(child_object, "sensitive", true)
      object = Map.put(object, "object", child_object)
    end

    {:ok, object}
  end

  @ftl_removal Keyword.get(@mrf_policy, :federated_timeline_removal)
  defp check_ftl_removal(actor_info, object) do
    if actor_info.host in @ftl_removal do
      user = User.get_by_ap_id(object["actor"])

      # flip to/cc relationship to make the post unlisted
      if "https://www.w3.org/ns/activitystreams#Public" in object["to"] and
           user.follower_address in object["cc"] do
        to =
          List.delete(object["to"], "https://www.w3.org/ns/activitystreams#Public") ++
            [user.follower_address]

        cc =
          List.delete(object["cc"], user.follower_address) ++
            ["https://www.w3.org/ns/activitystreams#Public"]

        object = Map.put(object, "to", to)
        object = Map.put(object, "cc", cc)
      end
    end

    {:ok, object}
  end

  def filter(object) do
    actor_info = URI.parse(object["actor"])

    with {:ok, object} <- check_reject(actor_info, object),
         {:ok, object} <- check_media_removal(actor_info, object),
         {:ok, object} <- check_media_nsfw(actor_info, object),
         {:ok, object} <- check_ftl_removal(actor_info, object) do
      {:ok, object}
    else
      _e -> {:reject, nil}
    end
  end
end
