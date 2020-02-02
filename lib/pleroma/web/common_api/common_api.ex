# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI do
  alias Pleroma.Activity
  alias Pleroma.ActivityExpiration
  alias Pleroma.Conversation.Participation
  alias Pleroma.Formatter
  alias Pleroma.Object
  alias Pleroma.ThreadMute
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.ActivityPub.Visibility

  import Pleroma.Web.Gettext
  import Pleroma.Web.CommonAPI.Utils

  require Pleroma.Constants

  def follow(follower, followed) do
    with {:ok, follower} <- User.maybe_direct_follow(follower, followed),
         {:ok, activity} <- ActivityPub.follow(follower, followed),
         {:ok, follower, followed} <-
           User.wait_and_refresh(
             Pleroma.Config.get([:activitypub, :follow_handshake_timeout]),
             follower,
             followed
           ) do
      {:ok, follower, followed, activity}
    end
  end

  def unfollow(follower, unfollowed) do
    with {:ok, follower, _follow_activity} <- User.unfollow(follower, unfollowed),
         {:ok, _activity} <- ActivityPub.unfollow(follower, unfollowed),
         {:ok, _unfollowed} <- User.unsubscribe(follower, unfollowed) do
      {:ok, follower}
    end
  end

  def accept_follow_request(follower, followed) do
    with {:ok, follower} <- User.follow(follower, followed),
         %Activity{} = follow_activity <- Utils.fetch_latest_follow(follower, followed),
         {:ok, follow_activity} <- Utils.update_follow_state_for_all(follow_activity, "accept"),
         {:ok, _activity} <-
           ActivityPub.accept(%{
             to: [follower.ap_id],
             actor: followed,
             object: follow_activity.data["id"],
             type: "Accept"
           }) do
      {:ok, follower}
    end
  end

  def reject_follow_request(follower, followed) do
    with %Activity{} = follow_activity <- Utils.fetch_latest_follow(follower, followed),
         {:ok, follow_activity} <- Utils.update_follow_state_for_all(follow_activity, "reject"),
         {:ok, _activity} <-
           ActivityPub.reject(%{
             to: [follower.ap_id],
             actor: followed,
             object: follow_activity.data["id"],
             type: "Reject"
           }) do
      {:ok, follower}
    end
  end

  def delete(activity_id, user) do
    with %Activity{data: %{"object" => _}} = activity <-
           Activity.get_by_id_with_object(activity_id),
         %Object{} = object <- Object.normalize(activity),
         true <- User.superuser?(user) || user.ap_id == object.data["actor"],
         {:ok, _} <- unpin(activity_id, user),
         {:ok, delete} <- ActivityPub.delete(object) do
      {:ok, delete}
    else
      _ ->
        {:error, dgettext("errors", "Could not delete")}
    end
  end

  def repeat(id_or_ap_id, user) do
    with %Activity{} = activity <- get_by_id_or_ap_id(id_or_ap_id),
         object <- Object.normalize(activity),
         nil <- Utils.get_existing_announce(user.ap_id, object) do
      ActivityPub.announce(user, object)
    else
      _ ->
        {:error, dgettext("errors", "Could not repeat")}
    end
  end

  def unrepeat(id_or_ap_id, user) do
    with %Activity{} = activity <- get_by_id_or_ap_id(id_or_ap_id),
         object <- Object.normalize(activity) do
      ActivityPub.unannounce(user, object)
    else
      _ ->
        {:error, dgettext("errors", "Could not unrepeat")}
    end
  end

  def favorite(id_or_ap_id, user) do
    with %Activity{} = activity <- get_by_id_or_ap_id(id_or_ap_id),
         object <- Object.normalize(activity),
         nil <- Utils.get_existing_like(user.ap_id, object) do
      ActivityPub.like(user, object)
    else
      _ ->
        {:error, dgettext("errors", "Could not favorite")}
    end
  end

  def unfavorite(id_or_ap_id, user) do
    with %Activity{} = activity <- get_by_id_or_ap_id(id_or_ap_id),
         object <- Object.normalize(activity) do
      ActivityPub.unlike(user, object)
    else
      _ ->
        {:error, dgettext("errors", "Could not unfavorite")}
    end
  end

  def vote(user, object, choices) do
    with "Question" <- object.data["type"],
         {:author, false} <- {:author, object.data["actor"] == user.ap_id},
         {:existing_votes, []} <- {:existing_votes, Utils.get_existing_votes(user.ap_id, object)},
         {options, max_count} <- get_options_and_max_count(object),
         option_count <- Enum.count(options),
         {:choice_check, {choices, true}} <-
           {:choice_check, normalize_and_validate_choice_indices(choices, option_count)},
         {:count_check, true} <- {:count_check, Enum.count(choices) <= max_count} do
      answer_activities =
        Enum.map(choices, fn index ->
          answer_data = make_answer_data(user, object, Enum.at(options, index)["name"])

          {:ok, activity} =
            ActivityPub.create(%{
              to: answer_data["to"],
              actor: user,
              context: object.data["context"],
              object: answer_data,
              additional: %{"cc" => answer_data["cc"]}
            })

          activity
        end)

      object = Object.get_cached_by_ap_id(object.data["id"])
      {:ok, answer_activities, object}
    else
      {:author, _} -> {:error, dgettext("errors", "Poll's author can't vote")}
      {:existing_votes, _} -> {:error, dgettext("errors", "Already voted")}
      {:choice_check, {_, false}} -> {:error, dgettext("errors", "Invalid indices")}
      {:count_check, false} -> {:error, dgettext("errors", "Too many choices")}
    end
  end

  defp get_options_and_max_count(object) do
    if Map.has_key?(object.data, "anyOf") do
      {object.data["anyOf"], Enum.count(object.data["anyOf"])}
    else
      {object.data["oneOf"], 1}
    end
  end

  defp normalize_and_validate_choice_indices(choices, count) do
    Enum.map_reduce(choices, true, fn index, valid ->
      index = if is_binary(index), do: String.to_integer(index), else: index
      {index, if(valid, do: index < count, else: valid)}
    end)
  end

  def get_visibility(_, _, %Participation{}) do
    {"direct", "direct"}
  end

  def get_visibility(%{"visibility" => visibility}, in_reply_to, _)
      when visibility in ~w{public unlisted private direct},
      do: {visibility, get_replied_to_visibility(in_reply_to)}

  def get_visibility(%{"visibility" => "list:" <> list_id}, in_reply_to, _) do
    visibility = {:list, String.to_integer(list_id)}
    {visibility, get_replied_to_visibility(in_reply_to)}
  end

  def get_visibility(_, in_reply_to, _) when not is_nil(in_reply_to) do
    visibility = get_replied_to_visibility(in_reply_to)
    {visibility, visibility}
  end

  def get_visibility(_, in_reply_to, _), do: {"public", get_replied_to_visibility(in_reply_to)}

  def get_replied_to_visibility(nil), do: nil

  def get_replied_to_visibility(activity) do
    with %Object{} = object <- Object.normalize(activity) do
      Pleroma.Web.ActivityPub.Visibility.get_visibility(object)
    end
  end

  defp check_expiry_date({:ok, nil} = res), do: res

  defp check_expiry_date({:ok, in_seconds}) do
    expiry = NaiveDateTime.utc_now() |> NaiveDateTime.add(in_seconds)

    if ActivityExpiration.expires_late_enough?(expiry) do
      {:ok, expiry}
    else
      {:error, "Expiry date is too soon"}
    end
  end

  defp check_expiry_date(expiry_str) do
    Ecto.Type.cast(:integer, expiry_str)
    |> check_expiry_date()
  end

  def post(user, %{"status" => status} = data) do
    limit = Pleroma.Config.get([:instance, :limit])

    with status <- String.trim(status),
         attachments <- attachments_from_ids(data),
         in_reply_to <- get_replied_to_activity(data["in_reply_to_status_id"]),
         in_reply_to_conversation <- Participation.get(data["in_reply_to_conversation_id"]),
         {visibility, in_reply_to_visibility} <-
           get_visibility(data, in_reply_to, in_reply_to_conversation),
         {_, false} <-
           {:private_to_public, in_reply_to_visibility == "direct" && visibility != "direct"},
         {content_html, mentions, tags} <-
           make_content_html(
             status,
             attachments,
             data,
             visibility
           ),
         mentioned_users <- for({_, mentioned_user} <- mentions, do: mentioned_user.ap_id),
         addressed_users <- get_addressed_users(mentioned_users, data["to"]),
         {poll, poll_emoji} <- make_poll_data(data),
         {to, cc} <-
           get_to_and_cc(user, addressed_users, in_reply_to, visibility, in_reply_to_conversation),
         context <- make_context(in_reply_to, in_reply_to_conversation),
         cw <- data["spoiler_text"] || "",
         sensitive <- data["sensitive"] || Enum.member?(tags, {"#nsfw", "nsfw"}),
         {:ok, expires_at} <- check_expiry_date(data["expires_in"]),
         full_payload <- String.trim(status <> cw),
         :ok <- validate_character_limit(full_payload, attachments, limit),
         object <-
           make_note_data(
             user.ap_id,
             to,
             context,
             content_html,
             attachments,
             in_reply_to,
             tags,
             cw,
             cc,
             sensitive,
             poll
           ),
         object <-
           Map.put(
             object,
             "emoji",
             Map.merge(Formatter.get_emoji_map(full_payload), poll_emoji)
           ) do
      preview? = Pleroma.Web.ControllerHelper.truthy_param?(data["preview"]) || false
      direct? = visibility == "direct"

      result =
        %{
          to: to,
          actor: user,
          context: context,
          object: object,
          additional: %{"cc" => cc, "directMessage" => direct?}
        }
        |> maybe_add_list_data(user, visibility)
        |> ActivityPub.create(preview?)

      if expires_at do
        with {:ok, activity} <- result do
          {:ok, _} = ActivityExpiration.create(activity, expires_at)
        end
      end

      result
    else
      {:private_to_public, true} ->
        {:error, dgettext("errors", "The message visibility must be direct")}

      {:error, _} = e ->
        e

      e ->
        {:error, e}
    end
  end

  # Updates the emojis for a user based on their profile
  def update(user) do
    user =
      with emoji <- emoji_from_profile(user),
           source_data <- (user.info.source_data || %{}) |> Map.put("tag", emoji),
           info_cng <- User.Info.set_source_data(user.info, source_data),
           change <- Ecto.Changeset.change(user) |> Ecto.Changeset.put_embed(:info, info_cng),
           {:ok, user} <- User.update_and_set_cache(change) do
        user
      else
        _e ->
          user
      end

    ActivityPub.update(%{
      local: true,
      to: [Pleroma.Constants.as_public(), user.follower_address],
      cc: [],
      actor: user.ap_id,
      object: Pleroma.Web.ActivityPub.UserView.render("user.json", %{user: user})
    })
  end

  def pin(id_or_ap_id, %{ap_id: user_ap_id} = user) do
    with %Activity{
           actor: ^user_ap_id,
           data: %{"type" => "Create"},
           object: %Object{data: %{"type" => object_type}}
         } = activity <- get_by_id_or_ap_id(id_or_ap_id),
         true <- object_type in ["Note", "Article", "Question"],
         true <- Visibility.is_public?(activity),
         %{valid?: true} = info_changeset <- User.Info.add_pinnned_activity(user.info, activity),
         changeset <-
           Ecto.Changeset.change(user) |> Ecto.Changeset.put_embed(:info, info_changeset),
         {:ok, _user} <- User.update_and_set_cache(changeset) do
      {:ok, activity}
    else
      %{errors: [pinned_activities: {err, _}]} ->
        {:error, err}

      _ ->
        {:error, dgettext("errors", "Could not pin")}
    end
  end

  def unpin(id_or_ap_id, user) do
    with %Activity{} = activity <- get_by_id_or_ap_id(id_or_ap_id),
         %{valid?: true} = info_changeset <-
           User.Info.remove_pinnned_activity(user.info, activity),
         changeset <-
           Ecto.Changeset.change(user) |> Ecto.Changeset.put_embed(:info, info_changeset),
         {:ok, _user} <- User.update_and_set_cache(changeset) do
      {:ok, activity}
    else
      %{errors: [pinned_activities: {err, _}]} ->
        {:error, err}

      _ ->
        {:error, dgettext("errors", "Could not unpin")}
    end
  end

  def add_mute(user, activity) do
    with {:ok, _} <- ThreadMute.add_mute(user.id, activity.data["context"]) do
      {:ok, activity}
    else
      {:error, _} -> {:error, dgettext("errors", "conversation is already muted")}
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
         {:account, %User{} = account} <- {:account, User.get_cached_by_id(account_id)},
         {:ok, {content_html, _, _}} <- make_report_content_html(data["comment"]),
         {:ok, statuses} <- get_report_statuses(account, data),
         {:ok, activity} <-
           ActivityPub.flag(%{
             context: Utils.generate_context_id(),
             actor: user,
             account: account,
             statuses: statuses,
             content: content_html,
             forward: data["forward"] || false
           }) do
      {:ok, activity}
    else
      {:error, err} -> {:error, err}
      {:account_id, %{}} -> {:error, dgettext("errors", "Valid `account_id` required")}
      {:account, nil} -> {:error, dgettext("errors", "Account not found")}
    end
  end

  def update_report_state(activity_id, state) do
    with %Activity{} = activity <- Activity.get_by_id(activity_id),
         {:ok, activity} <- Utils.update_report_state(activity, state) do
      {:ok, activity}
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
      _ -> {:error, dgettext("errors", "Could not update state")}
    end
  end

  def update_activity_scope(activity_id, opts \\ %{}) do
    with %Activity{} = activity <- Activity.get_by_id_with_object(activity_id),
         {:ok, activity} <- toggle_sensitive(activity, opts),
         {:ok, activity} <- set_visibility(activity, opts) do
      {:ok, activity}
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp toggle_sensitive(activity, %{"sensitive" => sensitive}) when sensitive in ~w(true false) do
    toggle_sensitive(activity, %{"sensitive" => String.to_existing_atom(sensitive)})
  end

  defp toggle_sensitive(%Activity{object: object} = activity, %{"sensitive" => sensitive})
       when is_boolean(sensitive) do
    new_data = Map.put(object.data, "sensitive", sensitive)

    {:ok, object} =
      object
      |> Object.change(%{data: new_data})
      |> Object.update_and_set_cache()

    {:ok, Map.put(activity, :object, object)}
  end

  defp toggle_sensitive(activity, _), do: {:ok, activity}

  defp set_visibility(activity, %{"visibility" => visibility}) do
    Utils.update_activity_visibility(activity, visibility)
  end

  defp set_visibility(activity, _), do: {:ok, activity}

  def hide_reblogs(user, muted) do
    ap_id = muted.ap_id

    if ap_id not in user.info.muted_reblogs do
      info_changeset = User.Info.add_reblog_mute(user.info, ap_id)
      changeset = Ecto.Changeset.change(user) |> Ecto.Changeset.put_embed(:info, info_changeset)
      User.update_and_set_cache(changeset)
    end
  end

  def show_reblogs(user, muted) do
    ap_id = muted.ap_id

    if ap_id in user.info.muted_reblogs do
      info_changeset = User.Info.remove_reblog_mute(user.info, ap_id)
      changeset = Ecto.Changeset.change(user) |> Ecto.Changeset.put_embed(:info, info_changeset)
      User.update_and_set_cache(changeset)
    end
  end
end
