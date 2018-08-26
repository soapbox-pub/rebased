defmodule Pleroma.Web.CommonAPI do
  alias Pleroma.{User, Repo, Activity, Object}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Formatter

  import Pleroma.Web.CommonAPI.Utils

  def delete(activity_id, user) do
    with %Activity{data: %{"object" => %{"id" => object_id}}} <- Repo.get(Activity, activity_id),
         %Object{} = object <- Object.normalize(object_id),
         true <- user.info["is_moderator"] || user.ap_id == object.data["actor"],
         {:ok, delete} <- ActivityPub.delete(object) do
      {:ok, delete}
    end
  end

  def repeat(id_or_ap_id, user) do
    with %Activity{} = activity <- get_by_id_or_ap_id(id_or_ap_id),
         object <- Object.normalize(activity.data["object"]["id"]) do
      ActivityPub.announce(user, object)
    else
      _ ->
        {:error, "Could not repeat"}
    end
  end

  def unrepeat(id_or_ap_id, user) do
    with %Activity{} = activity <- get_by_id_or_ap_id(id_or_ap_id),
         object <- Object.normalize(activity.data["object"]["id"]) do
      ActivityPub.unannounce(user, object)
    else
      _ ->
        {:error, "Could not unrepeat"}
    end
  end

  def favorite(id_or_ap_id, user) do
    with %Activity{} = activity <- get_by_id_or_ap_id(id_or_ap_id),
         false <- activity.data["actor"] == user.ap_id,
         object <- Object.normalize(activity.data["object"]["id"]) do
      ActivityPub.like(user, object)
    else
      _ ->
        {:error, "Could not favorite"}
    end
  end

  def unfavorite(id_or_ap_id, user) do
    with %Activity{} = activity <- get_by_id_or_ap_id(id_or_ap_id),
         false <- activity.data["actor"] == user.ap_id,
         object <- Object.normalize(activity.data["object"]["id"]) do
      ActivityPub.unlike(user, object)
    else
      _ ->
        {:error, "Could not unfavorite"}
    end
  end

  def get_visibility(%{"visibility" => visibility})
      when visibility in ~w{public unlisted private direct},
      do: visibility

  def get_visibility(%{"in_reply_to_status_id" => status_id}) when not is_nil(status_id) do
    case get_replied_to_activity(status_id) do
      nil ->
        "public"

      inReplyTo ->
        Pleroma.Web.MastodonAPI.StatusView.get_visibility(inReplyTo.data["object"])
    end
  end

  def get_visibility(_), do: "public"

  @instance Application.get_env(:pleroma, :instance)
  @limit Keyword.get(@instance, :limit)
  def post(user, %{"status" => status} = data) do
    visibility = get_visibility(data)

    with status <- String.trim(status),
         length when length in 1..@limit <- String.length(status),
         attachments <- attachments_from_ids(data["media_ids"]),
         mentions <- Formatter.parse_mentions(status),
         inReplyTo <- get_replied_to_activity(data["in_reply_to_status_id"]),
         {to, cc} <- to_for_user_and_mentions(user, mentions, inReplyTo, visibility),
         tags <- Formatter.parse_tags(status, data),
         content_html <-
           make_content_html(status, mentions, attachments, tags, data["no_attachment_links"]),
         context <- make_context(inReplyTo),
         cw <- data["spoiler_text"],
         object <-
           make_note_data(
             user.ap_id,
             to,
             context,
             content_html,
             attachments,
             inReplyTo,
             tags,
             cw,
             cc
           ),
         object <-
           Map.put(
             object,
             "emoji",
             Formatter.get_emoji(status)
             |> Enum.reduce(%{}, fn {name, file}, acc ->
               Map.put(acc, name, "#{Pleroma.Web.Endpoint.static_url()}#{file}")
             end)
           ) do
      res =
        ActivityPub.create(%{
          to: to,
          actor: user,
          context: context,
          object: object,
          additional: %{"cc" => cc}
        })

      res
    end
  end

  def update(user) do
    user =
      with emoji <- emoji_from_profile(user),
           source_data <- (user.info["source_data"] || %{}) |> Map.put("tag", emoji),
           new_info <- Map.put(user.info, "source_data", source_data),
           change <- User.info_changeset(user, %{info: new_info}),
           {:ok, user} <- User.update_and_set_cache(change) do
        user
      else
        _e ->
          user
      end

    ActivityPub.update(%{
      local: true,
      to: [user.follower_address],
      cc: [],
      actor: user.ap_id,
      object: Pleroma.Web.ActivityPub.UserView.render("user.json", %{user: user})
    })
  end
end
