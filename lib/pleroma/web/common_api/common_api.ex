# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI do
  alias Pleroma.User
  alias Pleroma.Repo
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.ThreadMute
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Formatter

  import Pleroma.Web.CommonAPI.Utils

  def delete(activity_id, user) do
    with %Activity{data: %{"object" => %{"id" => object_id}}} <- Repo.get(Activity, activity_id),
         %Object{} = object <- Object.normalize(object_id),
         true <- user.info.is_moderator || user.ap_id == object.data["actor"],
         {:ok, _} <- unpin(activity_id, user),
         {:ok, delete} <- ActivityPub.delete(object) do
      {:ok, delete}
    end
  end

  def repeat(id_or_ap_id, user) do
    with %Activity{} = activity <- get_by_id_or_ap_id(id_or_ap_id),
         object <- Object.normalize(activity.data["object"]["id"]),
         nil <- Utils.get_existing_announce(user.ap_id, object) do
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
         object <- Object.normalize(activity.data["object"]["id"]),
         nil <- Utils.get_existing_like(user.ap_id, object) do
      ActivityPub.like(user, object)
    else
      _ ->
        {:error, "Could not favorite"}
    end
  end

  def unfavorite(id_or_ap_id, user) do
    with %Activity{} = activity <- get_by_id_or_ap_id(id_or_ap_id),
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

  def post(user, %{"status" => status} = data) do
    visibility = get_visibility(data)
    limit = Pleroma.Config.get([:instance, :limit])

    with status <- String.trim(status),
         attachments <- attachments_from_ids(data),
         inReplyTo <- get_replied_to_activity(data["in_reply_to_status_id"]),
         {content_html, mentions, tags} <-
           make_content_html(
             status,
             attachments,
             data
           ),
         {to, cc} <- to_for_user_and_mentions(user, mentions, inReplyTo, visibility),
         context <- make_context(inReplyTo),
         cw <- data["spoiler_text"],
         full_payload <- String.trim(status <> (data["spoiler_text"] || "")),
         length when length in 1..limit <- String.length(full_payload),
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
             (Formatter.get_emoji(status) ++ Formatter.get_emoji(data["spoiler_text"]))
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
          additional: %{"cc" => cc, "directMessage" => visibility == "direct"}
        })

      res
    end
  end

  # Updates the emojis for a user based on their profile
  def update(user) do
    user =
      with emoji <- emoji_from_profile(user),
           source_data <- (user.info.source_data || %{}) |> Map.put("tag", emoji),
           info_cng <- Pleroma.User.Info.set_source_data(user.info, source_data),
           change <- Ecto.Changeset.change(user) |> Ecto.Changeset.put_embed(:info, info_cng),
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

  def pin(id_or_ap_id, %{ap_id: user_ap_id} = user) do
    with %Activity{
           actor: ^user_ap_id,
           data: %{
             "type" => "Create",
             "object" => %{
               "to" => object_to,
               "type" => "Note"
             }
           }
         } = activity <- get_by_id_or_ap_id(id_or_ap_id),
         true <- Enum.member?(object_to, "https://www.w3.org/ns/activitystreams#Public"),
         %{valid?: true} = info_changeset <-
           Pleroma.User.Info.add_pinnned_activity(user.info, activity),
         changeset <-
           Ecto.Changeset.change(user) |> Ecto.Changeset.put_embed(:info, info_changeset),
         {:ok, _user} <- User.update_and_set_cache(changeset) do
      {:ok, activity}
    else
      %{errors: [pinned_activities: {err, _}]} ->
        {:error, err}

      _ ->
        {:error, "Could not pin"}
    end
  end

  def unpin(id_or_ap_id, user) do
    with %Activity{} = activity <- get_by_id_or_ap_id(id_or_ap_id),
         %{valid?: true} = info_changeset <-
           Pleroma.User.Info.remove_pinnned_activity(user.info, activity),
         changeset <-
           Ecto.Changeset.change(user) |> Ecto.Changeset.put_embed(:info, info_changeset),
         {:ok, _user} <- User.update_and_set_cache(changeset) do
      {:ok, activity}
    else
      %{errors: [pinned_activities: {err, _}]} ->
        {:error, err}

      _ ->
        {:error, "Could not unpin"}
    end
  end

  def add_mute(user, activity) do
    with {:ok, _} <- ThreadMute.add_mute(user.id, activity.data["context"]) do
      {:ok, activity}
    else
      {:error, _} -> {:error, "conversation is already muted"}
    end
  end

  def remove_mute(user, activity) do
    ThreadMute.remove_mute(user.id, activity.data["context"])
    {:ok, activity}
  end

  def thread_muted?(%{id: nil} = _user, _activity), do: false

  def thread_muted?(user, activity) do
    with [] <- ThreadMute.check_muted(user.id, activity.data["context"]) do
      false
    else
      _ -> true
    end
  end

  def report(user, data) do
    with {:account_id, %{"account_id" => account_id}} <- {:account_id, data},
         {:account, %User{} = account} <- {:account, User.get_by_id(account_id)},
         {:ok, {content_html, _, _}} <- make_report_content_html(data["comment"]),
         {:ok, statuses} <- get_report_statuses(account, data),
         {:ok, activity} <-
           ActivityPub.flag(%{
             context: Utils.generate_context_id(),
             actor: user,
             account: account,
             statuses: statuses,
             content: content_html
           }) do
      Enum.each(User.all_superusers(), fn superuser ->
        superuser
        |> Pleroma.AdminEmail.report(user, account, statuses, content_html)
        |> Pleroma.Mailer.deliver_async()
      end)

      {:ok, activity}
    else
      {:error, err} -> {:error, err}
      {:account_id, %{}} -> {:error, "Valid `account_id` required"}
      {:account, nil} -> {:error, "Account not found"}
    end
  end
end
