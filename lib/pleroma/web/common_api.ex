# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI do
  alias Pleroma.Activity
  alias Pleroma.Conversation.Participation
  alias Pleroma.Formatter
  alias Pleroma.Object
  alias Pleroma.Rule
  alias Pleroma.ThreadMute
  alias Pleroma.User
  alias Pleroma.UserRelationship
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.Pipeline
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.CommonAPI.ActivityDraft

  import Pleroma.Web.Gettext
  import Pleroma.Web.CommonAPI.Utils

  require Pleroma.Constants
  require Logger

  def block(blocker, blocked) do
    with {:ok, block_data, _} <- Builder.block(blocker, blocked),
         {:ok, block, _} <- Pipeline.common_pipeline(block_data, local: true) do
      {:ok, block}
    end
  end

  def post_chat_message(%User{} = user, %User{} = recipient, content, opts \\ []) do
    with maybe_attachment <- opts[:media_id] && Object.get_by_id(opts[:media_id]),
         :ok <- validate_chat_content_length(content, !!maybe_attachment),
         {_, {:ok, chat_message_data, _meta}} <-
           {:build_object,
            Builder.chat_message(
              user,
              recipient.ap_id,
              content |> format_chat_content,
              attachment: maybe_attachment
            )},
         {_, {:ok, create_activity_data, _meta}} <-
           {:build_create_activity, Builder.create(user, chat_message_data, [recipient.ap_id])},
         {_, {:ok, %Activity{} = activity, _meta}} <-
           {:common_pipeline,
            Pipeline.common_pipeline(create_activity_data,
              local: true,
              idempotency_key: opts[:idempotency_key]
            )} do
      {:ok, activity}
    else
      {:common_pipeline, {:reject, _} = e} -> e
      e -> e
    end
  end

  defp format_chat_content(nil), do: nil

  defp format_chat_content(content) do
    {text, _, _} =
      content
      |> Formatter.html_escape("text/plain")
      |> Formatter.linkify()
      |> (fn {text, mentions, tags} ->
            {String.replace(text, ~r/\r?\n/, "<br>"), mentions, tags}
          end).()

    text
  end

  defp validate_chat_content_length(_, true), do: :ok
  defp validate_chat_content_length(nil, false), do: {:error, :no_content}

  defp validate_chat_content_length(content, _) do
    if String.length(content) <= Pleroma.Config.get([:instance, :chat_limit]) do
      :ok
    else
      {:error, :content_too_long}
    end
  end

  def unblock(blocker, blocked) do
    with {_, %Activity{} = block} <- {:fetch_block, Utils.fetch_latest_block(blocker, blocked)},
         {:ok, unblock_data, _} <- Builder.undo(blocker, block),
         {:ok, unblock, _} <- Pipeline.common_pipeline(unblock_data, local: true) do
      {:ok, unblock}
    else
      {:fetch_block, nil} ->
        if User.blocks?(blocker, blocked) do
          User.unblock(blocker, blocked)
          {:ok, :no_activity}
        else
          {:error, :not_blocking}
        end

      e ->
        e
    end
  end

  def follow(follower, followed) do
    timeout = Pleroma.Config.get([:activitypub, :follow_handshake_timeout])

    with {:ok, follow_data, _} <- Builder.follow(follower, followed),
         {:ok, activity, _} <- Pipeline.common_pipeline(follow_data, local: true),
         {:ok, follower, followed} <- User.wait_and_refresh(timeout, follower, followed) do
      if activity.data["state"] == "reject" do
        {:error, :rejected}
      else
        {:ok, follower, followed, activity}
      end
    end
  end

  def unfollow(follower, unfollowed) do
    with {:ok, follower, _follow_activity} <- User.unfollow(follower, unfollowed),
         {:ok, _activity} <- ActivityPub.unfollow(follower, unfollowed),
         {:ok, _subscription} <- User.unsubscribe(follower, unfollowed),
         {:ok, _endorsement} <- User.unendorse(follower, unfollowed) do
      {:ok, follower}
    end
  end

  def accept_follow_request(follower, followed) do
    with %Activity{} = follow_activity <- Utils.fetch_latest_follow(follower, followed),
         {:ok, accept_data, _} <- Builder.accept(followed, follow_activity),
         {:ok, _activity, _} <- Pipeline.common_pipeline(accept_data, local: true) do
      {:ok, follower}
    end
  end

  def reject_follow_request(follower, followed) do
    with %Activity{} = follow_activity <- Utils.fetch_latest_follow(follower, followed),
         {:ok, reject_data, _} <- Builder.reject(followed, follow_activity),
         {:ok, _activity, _} <- Pipeline.common_pipeline(reject_data, local: true) do
      {:ok, follower}
    end
  end

  def delete(activity_id, user) do
    with {_, %Activity{data: %{"object" => _, "type" => "Create"}} = activity} <-
           {:find_activity, Activity.get_by_id(activity_id)},
         {_, %Object{} = object, _} <-
           {:find_object, Object.normalize(activity, fetch: false), activity},
         true <- User.superuser?(user) || user.ap_id == object.data["actor"],
         {:ok, delete_data, _} <- Builder.delete(user, object.data["id"]),
         {:ok, delete, _} <- Pipeline.common_pipeline(delete_data, local: true) do
      {:ok, delete}
    else
      {:find_activity, _} ->
        {:error, :not_found}

      {:find_object, nil, %Activity{data: %{"actor" => actor, "object" => object}}} ->
        # We have the create activity, but not the object, it was probably pruned.
        # Insert a tombstone and try again
        with {:ok, tombstone_data, _} <- Builder.tombstone(actor, object),
             {:ok, _tombstone} <- Object.create(tombstone_data) do
          delete(activity_id, user)
        else
          _ ->
            Logger.error(
              "Could not insert tombstone for missing object on deletion. Object is #{object}."
            )

            {:error, dgettext("errors", "Could not delete")}
        end

      _ ->
        {:error, dgettext("errors", "Could not delete")}
    end
  end

  def repeat(id, user, params \\ %{}) do
    with %Activity{data: %{"type" => "Create"}} = activity <- Activity.get_by_id(id),
         object = %Object{} <- Object.normalize(activity, fetch: false),
         {_, nil} <- {:existing_announce, Utils.get_existing_announce(user.ap_id, object)},
         public = public_announce?(object, params),
         {:ok, announce, _} <- Builder.announce(user, object, public: public),
         {:ok, activity, _} <- Pipeline.common_pipeline(announce, local: true) do
      {:ok, activity}
    else
      {:existing_announce, %Activity{} = announce} ->
        {:ok, announce}

      _ ->
        {:error, :not_found}
    end
  end

  def unrepeat(id, user) do
    with {_, %Activity{data: %{"type" => "Create"}} = activity} <-
           {:find_activity, Activity.get_by_id(id)},
         %Object{} = note <- Object.normalize(activity, fetch: false),
         %Activity{} = announce <- Utils.get_existing_announce(user.ap_id, note),
         {:ok, undo, _} <- Builder.undo(user, announce),
         {:ok, activity, _} <- Pipeline.common_pipeline(undo, local: true) do
      {:ok, activity}
    else
      {:find_activity, _} -> {:error, :not_found}
      _ -> {:error, dgettext("errors", "Could not unrepeat")}
    end
  end

  @spec favorite(User.t(), binary()) :: {:ok, Activity.t() | :already_liked} | {:error, any()}
  def favorite(%User{} = user, id) do
    case favorite_helper(user, id) do
      {:ok, _} = res ->
        res

      {:error, :not_found} = res ->
        res

      {:error, e} ->
        Logger.error("Could not favorite #{id}. Error: #{inspect(e, pretty: true)}")
        {:error, dgettext("errors", "Could not favorite")}
    end
  end

  def favorite_helper(user, id) do
    with {_, %Activity{object: object}} <- {:find_object, Activity.get_by_id_with_object(id)},
         {_, {:ok, like_object, meta}} <- {:build_object, Builder.like(user, object)},
         {_, {:ok, %Activity{} = activity, _meta}} <-
           {:common_pipeline,
            Pipeline.common_pipeline(like_object, Keyword.put(meta, :local, true))} do
      {:ok, activity}
    else
      {:find_object, _} ->
        {:error, :not_found}

      {:common_pipeline, {:error, {:validate, {:error, changeset}}}} = e ->
        if {:object, {"already liked by this actor", []}} in changeset.errors do
          {:ok, :already_liked}
        else
          {:error, e}
        end

      e ->
        {:error, e}
    end
  end

  def unfavorite(id, user) do
    with {_, %Activity{data: %{"type" => "Create"}} = activity} <-
           {:find_activity, Activity.get_by_id(id)},
         %Object{} = note <- Object.normalize(activity, fetch: false),
         %Activity{} = like <- Utils.get_existing_like(user.ap_id, note),
         {:ok, undo, _} <- Builder.undo(user, like),
         {:ok, activity, _} <- Pipeline.common_pipeline(undo, local: true) do
      {:ok, activity}
    else
      {:find_activity, _} -> {:error, :not_found}
      _ -> {:error, dgettext("errors", "Could not unfavorite")}
    end
  end

  def react_with_emoji(id, user, emoji) do
    with %Activity{} = activity <- Activity.get_by_id(id),
         object <- Object.normalize(activity, fetch: false),
         {:ok, emoji_react, _} <- Builder.emoji_react(user, object, emoji),
         {:ok, activity, _} <- Pipeline.common_pipeline(emoji_react, local: true) do
      {:ok, activity}
    else
      _ ->
        {:error, dgettext("errors", "Could not add reaction emoji")}
    end
  end

  def unreact_with_emoji(id, user, emoji) do
    with %Activity{} = reaction_activity <- Utils.get_latest_reaction(id, user, emoji),
         {:ok, undo, _} <- Builder.undo(user, reaction_activity),
         {:ok, activity, _} <- Pipeline.common_pipeline(undo, local: true) do
      {:ok, activity}
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
          {:ok, answer_object, _meta} =
            Builder.answer(user, object, Enum.at(options, index)["name"])

          {:ok, activity_data, _meta} = Builder.create(user, answer_object, [])

          {:ok, activity, _meta} =
            activity_data
            |> Map.put("cc", answer_object["cc"])
            |> Map.put("context", answer_object["context"])
            |> Pipeline.common_pipeline(local: true)

          # TODO: Do preload of Pleroma.Object in Pipeline
          Activity.normalize(activity.data)
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

  defp get_options_and_max_count(%{data: %{"anyOf" => any_of}})
       when is_list(any_of) and any_of != [],
       do: {any_of, Enum.count(any_of)}

  defp get_options_and_max_count(%{data: %{"oneOf" => one_of}})
       when is_list(one_of) and one_of != [],
       do: {one_of, 1}

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

  def public_announce?(_, %{visibility: visibility})
      when visibility in ~w{public unlisted private direct},
      do: visibility in ~w(public unlisted)

  def public_announce?(object, _) do
    Visibility.is_public?(object)
  end

  def get_visibility(_, _, %Participation{}), do: {"direct", "direct"}

  def get_visibility(%{visibility: visibility}, in_reply_to, _)
      when visibility in ~w{public local unlisted private direct},
      do: {visibility, get_replied_to_visibility(in_reply_to)}

  def get_visibility(%{visibility: "list:" <> list_id}, in_reply_to, _) do
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
    with %Object{} = object <- Object.normalize(activity, fetch: false) do
      Visibility.get_visibility(object)
    end
  end

  def check_expiry_date({:ok, nil} = res), do: res

  def check_expiry_date({:ok, in_seconds}) do
    expiry = DateTime.add(DateTime.utc_now(), in_seconds)

    if Pleroma.Workers.PurgeExpiredActivity.expires_late_enough?(expiry) do
      {:ok, expiry}
    else
      {:error, "Expiry date is too soon"}
    end
  end

  def check_expiry_date(expiry_str) do
    Ecto.Type.cast(:integer, expiry_str)
    |> check_expiry_date()
  end

  def listen(user, data) do
    with {:ok, draft} <- ActivityDraft.listen(user, data) do
      ActivityPub.listen(draft.changes)
    end
  end

  def post(user, %{status: _} = data) do
    with {:ok, draft} <- ActivityDraft.create(user, data) do
      ActivityPub.create(draft.changes, draft.preview?)
    end
  end

  @spec pin(String.t(), User.t()) :: {:ok, Activity.t()} | {:error, term()}
  def pin(id, %User{} = user) do
    with %Activity{} = activity <- create_activity_by_id(id),
         true <- activity_belongs_to_actor(activity, user.ap_id),
         true <- object_type_is_allowed_for_pin(activity.object),
         true <- activity_is_public(activity),
         {:ok, pin_data, _} <- Builder.pin(user, activity.object),
         {:ok, _pin, _} <-
           Pipeline.common_pipeline(pin_data,
             local: true,
             activity_id: id
           ) do
      {:ok, activity}
    else
      {:error, {:side_effects, error}} -> error
      error -> error
    end
  end

  defp create_activity_by_id(id) do
    with nil <- Activity.create_by_id_with_object(id) do
      {:error, :not_found}
    end
  end

  defp activity_belongs_to_actor(%{actor: actor}, actor), do: true
  defp activity_belongs_to_actor(_, _), do: {:error, :ownership_error}

  defp object_type_is_allowed_for_pin(%{data: %{"type" => type}}) do
    with false <- type in ["Note", "Article", "Question"] do
      {:error, :not_allowed}
    end
  end

  defp activity_is_public(activity) do
    with false <- Visibility.is_public?(activity) do
      {:error, :visibility_error}
    end
  end

  @spec unpin(String.t(), User.t()) :: {:ok, User.t()} | {:error, term()}
  def unpin(id, user) do
    with %Activity{} = activity <- create_activity_by_id(id),
         {:ok, unpin_data, _} <- Builder.unpin(user, activity.object),
         {:ok, _unpin, _} <-
           Pipeline.common_pipeline(unpin_data,
             local: true,
             activity_id: activity.id,
             expires_at: activity.data["expires_at"],
             featured_address: user.featured_address
           ) do
      {:ok, activity}
    end
  end

  def add_mute(user, activity, params \\ %{}) do
    expires_in = Map.get(params, :expires_in, 0)

    with {:ok, _} <- ThreadMute.add_mute(user.id, activity.data["context"]),
         _ <- Pleroma.Notification.mark_context_as_read(user, activity.data["context"]) do
      if expires_in > 0 do
        Pleroma.Workers.MuteExpireWorker.enqueue(
          "unmute_conversation",
          %{"user_id" => user.id, "activity_id" => activity.id},
          schedule_in: expires_in
        )
      end

      {:ok, activity}
    else
      {:error, _} -> {:error, dgettext("errors", "conversation is already muted")}
    end
  end

  def remove_mute(%User{} = user, %Activity{} = activity) do
    ThreadMute.remove_mute(user.id, activity.data["context"])
    {:ok, activity}
  end

  def remove_mute(user_id, activity_id) do
    with {:user, %User{} = user} <- {:user, User.get_by_id(user_id)},
         {:activity, %Activity{} = activity} <- {:activity, Activity.get_by_id(activity_id)} do
      remove_mute(user, activity)
    else
      {what, result} = error ->
        Logger.warn(
          "CommonAPI.remove_mute/2 failed. #{what}: #{result}, user_id: #{user_id}, activity_id: #{activity_id}"
        )

        {:error, error}
    end
  end

  def thread_muted?(%User{id: user_id}, %{data: %{"context" => context}})
      when is_binary(context) do
    ThreadMute.exists?(user_id, context)
  end

  def thread_muted?(_, _), do: false

  def report(user, data) do
    with {:ok, account} <- get_reported_account(data.account_id),
         {:ok, {content_html, _, _}} <- make_report_content_html(data[:comment]),
         {:ok, statuses} <- get_report_statuses(account, data),
         rules <- get_report_rules(Map.get(data, :rule_ids, nil)) do
      ActivityPub.flag(%{
        context: Utils.generate_context_id(),
        actor: user,
        account: account,
        statuses: statuses,
        content: content_html,
        forward: Map.get(data, :forward, false),
        rules: rules
      })
    end
  end

  defp get_reported_account(account_id) do
    case User.get_cached_by_id(account_id) do
      %User{} = account -> {:ok, account}
      _ -> {:error, dgettext("errors", "Account not found")}
    end
  end

  defp get_report_rules(nil) do
    nil
  end

  defp get_report_rules(rule_ids) do
    rule_ids
    |> Rule.get()
    |> Enum.map(& &1.id)
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

  defp toggle_sensitive(activity, %{sensitive: sensitive}) when sensitive in ~w(true false) do
    toggle_sensitive(activity, %{sensitive: String.to_existing_atom(sensitive)})
  end

  defp toggle_sensitive(%Activity{object: object} = activity, %{sensitive: sensitive})
       when is_boolean(sensitive) do
    new_data = Map.put(object.data, "sensitive", sensitive)

    {:ok, object} =
      object
      |> Object.change(%{data: new_data})
      |> Object.update_and_set_cache()

    {:ok, Map.put(activity, :object, object)}
  end

  defp toggle_sensitive(activity, _), do: {:ok, activity}

  defp set_visibility(activity, %{visibility: visibility}) do
    Utils.update_activity_visibility(activity, visibility)
  end

  defp set_visibility(activity, _), do: {:ok, activity}

  def hide_reblogs(%User{} = user, %User{} = target) do
    UserRelationship.create_reblog_mute(user, target)
  end

  def show_reblogs(%User{} = user, %User{} = target) do
    UserRelationship.delete_reblog_mute(user, target)
  end

  def get_user(ap_id, fake_record_fallback \\ true) do
    cond do
      user = User.get_cached_by_ap_id(ap_id) ->
        user

      user = User.get_by_guessed_nickname(ap_id) ->
        user

      fake_record_fallback ->
        # TODO: refactor (fake records is never a good idea)
        User.error_user(ap_id)

      true ->
        nil
    end
  end
end
