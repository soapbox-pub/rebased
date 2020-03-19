# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI do
  alias Pleroma.Activity
  alias Pleroma.ActivityExpiration
  alias Pleroma.Conversation.Participation
  alias Pleroma.FollowingRelationship
  alias Pleroma.Object
  alias Pleroma.ThreadMute
  alias Pleroma.User
  alias Pleroma.UserRelationship
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.Pipeline
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.ActivityPub.Visibility

  import Pleroma.Web.Gettext
  import Pleroma.Web.CommonAPI.Utils

  require Pleroma.Constants
  require Logger

  def follow(follower, followed) do
    timeout = Pleroma.Config.get([:activitypub, :follow_handshake_timeout])

    with {:ok, follower} <- User.maybe_direct_follow(follower, followed),
         {:ok, activity} <- ActivityPub.follow(follower, followed),
         {:ok, follower, followed} <- User.wait_and_refresh(timeout, follower, followed) do
      {:ok, follower, followed, activity}
    end
  end

  def unfollow(follower, unfollowed) do
    with {:ok, follower, _follow_activity} <- User.unfollow(follower, unfollowed),
         {:ok, _activity} <- ActivityPub.unfollow(follower, unfollowed),
         {:ok, _subscription} <- User.unsubscribe(follower, unfollowed) do
      {:ok, follower}
    end
  end

  def accept_follow_request(follower, followed) do
    with {:ok, follower} <- User.follow(follower, followed),
         %Activity{} = follow_activity <- Utils.fetch_latest_follow(follower, followed),
         {:ok, follow_activity} <- Utils.update_follow_state_for_all(follow_activity, "accept"),
         {:ok, _relationship} <- FollowingRelationship.update(follower, followed, "accept"),
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
         {:ok, _relationship} <- FollowingRelationship.update(follower, followed, "reject"),
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
    with {_, %Activity{data: %{"object" => _}} = activity} <-
           {:find_activity, Activity.get_by_id_with_object(activity_id)},
         %Object{} = object <- Object.normalize(activity),
         true <- User.superuser?(user) || user.ap_id == object.data["actor"],
         {:ok, _} <- unpin(activity_id, user),
         {:ok, delete} <- ActivityPub.delete(object) do
      {:ok, delete}
    else
      {:find_activity, _} -> {:error, :not_found}
      _ -> {:error, dgettext("errors", "Could not delete")}
    end
  end

  def repeat(id_or_ap_id, user, params \\ %{}) do
    with {_, %Activity{} = activity} <- {:find_activity, get_by_id_or_ap_id(id_or_ap_id)},
         object <- Object.normalize(activity),
         announce_activity <- Utils.get_existing_announce(user.ap_id, object),
         public <- public_announce?(object, params) do
      if announce_activity do
        {:ok, announce_activity, object}
      else
        ActivityPub.announce(user, object, nil, true, public)
      end
    else
      {:find_activity, _} -> {:error, :not_found}
      _ -> {:error, dgettext("errors", "Could not repeat")}
    end
  end

  def unrepeat(id_or_ap_id, user) do
    with {_, %Activity{} = activity} <- {:find_activity, get_by_id_or_ap_id(id_or_ap_id)} do
      object = Object.normalize(activity)
      ActivityPub.unannounce(user, object)
    else
      {:find_activity, _} -> {:error, :not_found}
      _ -> {:error, dgettext("errors", "Could not unrepeat")}
    end
  end

  @spec favorite(User.t(), binary()) :: {:ok, Activity.t()} | {:error, any()}
  def favorite(%User{} = user, id) do
    with {_, %Activity{object: object}} <- {:find_object, Activity.get_by_id_with_object(id)},
         {_, {:ok, like_object, meta}} <- {:build_object, Builder.like(user, object)},
         {_, {:ok, %Activity{} = activity, _meta}} <-
           {:common_pipeline,
            Pipeline.common_pipeline(like_object, Keyword.put(meta, :local, true))} do
      {:ok, activity}
    else
      {:find_object, _} ->
        {:error, :not_found}

      {:common_pipeline,
       {
         :error,
         {
           :validate_object,
           {
             :error,
             changeset
           }
         }
       }} = e ->
        if {:object, {"already liked by this actor", []}} in changeset.errors do
          {:ok, :already_liked}
        else
          Logger.error("Could not favorite #{id}. Error: #{inspect(e, pretty: true)}")
          {:error, dgettext("errors", "Could not favorite"), e}
        end

      e ->
        Logger.error("Could not favorite #{id}. Error: #{inspect(e, pretty: true)}")
        {:error, dgettext("errors", "Could not favorite"), e}
    end
  end

  def unfavorite(id_or_ap_id, user) do
    with {_, %Activity{} = activity} <- {:find_activity, get_by_id_or_ap_id(id_or_ap_id)} do
      object = Object.normalize(activity)
      ActivityPub.unlike(user, object)
    else
      {:find_activity, _} -> {:error, :not_found}
      _ -> {:error, dgettext("errors", "Could not unfavorite")}
    end
  end

  def react_with_emoji(id, user, emoji) do
    with %Activity{} = activity <- Activity.get_by_id(id),
         object <- Object.normalize(activity) do
      ActivityPub.react_with_emoji(user, object, emoji)
    else
      _ ->
        {:error, dgettext("errors", "Could not add reaction emoji")}
    end
  end

  def unreact_with_emoji(id, user, emoji) do
    with %Activity{} = reaction_activity <- Utils.get_latest_reaction(id, user, emoji) do
      ActivityPub.unreact_with_emoji(user, reaction_activity.data["id"])
    else
      _ ->
        {:error, dgettext("errors", "Could not remove reaction emoji")}
    end
  end

  def vote(user, %{data: %{"type" => "Question"}} = object, choices) do
    with :ok <- validate_not_author(object, user),
         :ok <- validate_existing_votes(user, object),
         {:ok, options, choices} <- normalize_and_validate_choices(choices, object) do
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
    end
  end

  defp validate_not_author(%{data: %{"actor" => ap_id}}, %{ap_id: ap_id}),
    do: {:error, dgettext("errors", "Poll's author can't vote")}

  defp validate_not_author(_, _), do: :ok

  defp validate_existing_votes(%{ap_id: ap_id}, object) do
    if Utils.get_existing_votes(ap_id, object) == [] do
      :ok
    else
      {:error, dgettext("errors", "Already voted")}
    end
  end

  defp get_options_and_max_count(%{data: %{"anyOf" => any_of}}), do: {any_of, Enum.count(any_of)}
  defp get_options_and_max_count(%{data: %{"oneOf" => one_of}}), do: {one_of, 1}

  defp normalize_and_validate_choices(choices, object) do
    choices = Enum.map(choices, fn i -> if is_binary(i), do: String.to_integer(i), else: i end)
    {options, max_count} = get_options_and_max_count(object)
    count = Enum.count(options)

    with {_, true} <- {:valid_choice, Enum.all?(choices, &(&1 < count))},
         {_, true} <- {:count_check, Enum.count(choices) <= max_count} do
      {:ok, options, choices}
    else
      {:valid_choice, _} -> {:error, dgettext("errors", "Invalid indices")}
      {:count_check, _} -> {:error, dgettext("errors", "Too many choices")}
    end
  end

  def public_announce?(_, %{"visibility" => visibility})
      when visibility in ~w{public unlisted private direct},
      do: visibility in ~w(public unlisted)

  def public_announce?(object, _) do
    Visibility.is_public?(object)
  end

  def get_visibility(_, _, %Participation{}), do: {"direct", "direct"}

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
      Visibility.get_visibility(object)
    end
  end

  def check_expiry_date({:ok, nil} = res), do: res

  def check_expiry_date({:ok, in_seconds}) do
    expiry = NaiveDateTime.utc_now() |> NaiveDateTime.add(in_seconds)

    if ActivityExpiration.expires_late_enough?(expiry) do
      {:ok, expiry}
    else
      {:error, "Expiry date is too soon"}
    end
  end

  def check_expiry_date(expiry_str) do
    Ecto.Type.cast(:integer, expiry_str)
    |> check_expiry_date()
  end

  def listen(user, %{"title" => _} = data) do
    with visibility <- data["visibility"] || "public",
         {to, cc} <- get_to_and_cc(user, [], nil, visibility, nil),
         listen_data <-
           Map.take(data, ["album", "artist", "title", "length"])
           |> Map.put("type", "Audio")
           |> Map.put("to", to)
           |> Map.put("cc", cc)
           |> Map.put("actor", user.ap_id),
         {:ok, activity} <-
           ActivityPub.listen(%{
             actor: user,
             to: to,
             object: listen_data,
             context: Utils.generate_context_id(),
             additional: %{"cc" => cc}
           }) do
      {:ok, activity}
    end
  end

  def post(user, %{"status" => _} = data) do
    with {:ok, draft} <- Pleroma.Web.CommonAPI.ActivityDraft.create(user, data) do
      draft.changes
      |> ActivityPub.create(draft.preview?)
      |> maybe_create_activity_expiration(draft.expires_at)
    end
  end

  defp maybe_create_activity_expiration({:ok, activity}, %NaiveDateTime{} = expires_at) do
    with {:ok, _} <- ActivityExpiration.create(activity, expires_at) do
      {:ok, activity}
    end
  end

  defp maybe_create_activity_expiration(result, _), do: result

  # Updates the emojis for a user based on their profile
  def update(user) do
    emoji = emoji_from_profile(user)
    source_data = Map.put(user.source_data, "tag", emoji)

    user =
      case User.update_source_data(user, source_data) do
        {:ok, user} -> user
        _ -> user
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
         {:ok, _user} <- User.add_pinnned_activity(user, activity) do
      {:ok, activity}
    else
      {:error, %{errors: [pinned_activities: {err, _}]}} -> {:error, err}
      _ -> {:error, dgettext("errors", "Could not pin")}
    end
  end

  def unpin(id_or_ap_id, user) do
    with %Activity{} = activity <- get_by_id_or_ap_id(id_or_ap_id),
         {:ok, _user} <- User.remove_pinnned_activity(user, activity) do
      {:ok, activity}
    else
      {:error, %{errors: [pinned_activities: {err, _}]}} -> {:error, err}
      _ -> {:error, dgettext("errors", "Could not unpin")}
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
    ThreadMute.check_muted(user.id, activity.data["context"]) != []
  end

  def report(user, %{"account_id" => account_id} = data) do
    with {:ok, account} <- get_reported_account(account_id),
         {:ok, {content_html, _, _}} <- make_report_content_html(data["comment"]),
         {:ok, statuses} <- get_report_statuses(account, data) do
      ActivityPub.flag(%{
        context: Utils.generate_context_id(),
        actor: user,
        account: account,
        statuses: statuses,
        content: content_html,
        forward: data["forward"] || false
      })
    end
  end

  def report(_user, _params), do: {:error, dgettext("errors", "Valid `account_id` required")}

  defp get_reported_account(account_id) do
    case User.get_cached_by_id(account_id) do
      %User{} = account -> {:ok, account}
      _ -> {:error, dgettext("errors", "Account not found")}
    end
  end

  def update_report_state(activity_ids, state) when is_list(activity_ids) do
    case Utils.update_report_state(activity_ids, state) do
      :ok -> {:ok, activity_ids}
      _ -> {:error, dgettext("errors", "Could not update state")}
    end
  end

  def update_report_state(activity_id, state) do
    with %Activity{} = activity <- Activity.get_by_id(activity_id) do
      Utils.update_report_state(activity, state)
    else
      nil -> {:error, :not_found}
      _ -> {:error, dgettext("errors", "Could not update state")}
    end
  end

  def update_activity_scope(activity_id, opts \\ %{}) do
    with %Activity{} = activity <- Activity.get_by_id_with_object(activity_id),
         {:ok, activity} <- toggle_sensitive(activity, opts) do
      set_visibility(activity, opts)
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

  def hide_reblogs(%User{} = user, %User{} = target) do
    UserRelationship.create_reblog_mute(user, target)
  end

  def show_reblogs(%User{} = user, %User{} = target) do
    UserRelationship.delete_reblog_mute(user, target)
  end
end
