# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ActivityPub do
  alias Pleroma.Activity
  alias Pleroma.Activity.Ir.Topics
  alias Pleroma.Config
  alias Pleroma.Conversation
  alias Pleroma.Conversation.Participation
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Object.Containment
  alias Pleroma.Object.Fetcher
  alias Pleroma.Pagination
  alias Pleroma.Repo
  alias Pleroma.Upload
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.MRF
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.Streamer
  alias Pleroma.Web.WebFinger
  alias Pleroma.Workers.BackgroundWorker

  import Ecto.Query
  import Pleroma.Web.ActivityPub.Utils
  import Pleroma.Web.ActivityPub.Visibility

  require Logger
  require Pleroma.Constants

  # For Announce activities, we filter the recipients based on following status for any actors
  # that match actual users.  See issue #164 for more information about why this is necessary.
  defp get_recipients(%{"type" => "Announce"} = data) do
    to = Map.get(data, "to", [])
    cc = Map.get(data, "cc", [])
    bcc = Map.get(data, "bcc", [])
    actor = User.get_cached_by_ap_id(data["actor"])

    recipients =
      Enum.filter(Enum.concat([to, cc, bcc]), fn recipient ->
        case User.get_cached_by_ap_id(recipient) do
          nil -> true
          user -> User.following?(user, actor)
        end
      end)

    {recipients, to, cc}
  end

  defp get_recipients(%{"type" => "Create"} = data) do
    to = Map.get(data, "to", [])
    cc = Map.get(data, "cc", [])
    bcc = Map.get(data, "bcc", [])
    actor = Map.get(data, "actor", [])
    recipients = [to, cc, bcc, [actor]] |> Enum.concat() |> Enum.uniq()
    {recipients, to, cc}
  end

  defp get_recipients(data) do
    to = Map.get(data, "to", [])
    cc = Map.get(data, "cc", [])
    bcc = Map.get(data, "bcc", [])
    recipients = Enum.concat([to, cc, bcc])
    {recipients, to, cc}
  end

  defp check_actor_is_active(actor) do
    if not is_nil(actor) do
      with user <- User.get_cached_by_ap_id(actor),
           false <- user.deactivated do
        true
      else
        _e -> false
      end
    else
      true
    end
  end

  defp check_remote_limit(%{"object" => %{"content" => content}}) when not is_nil(content) do
    limit = Config.get([:instance, :remote_limit])
    String.length(content) <= limit
  end

  defp check_remote_limit(_), do: true

  def increase_note_count_if_public(actor, object) do
    if is_public?(object), do: User.increase_note_count(actor), else: {:ok, actor}
  end

  def decrease_note_count_if_public(actor, object) do
    if is_public?(object), do: User.decrease_note_count(actor), else: {:ok, actor}
  end

  def increase_replies_count_if_reply(%{
        "object" => %{"inReplyTo" => reply_ap_id} = object,
        "type" => "Create"
      }) do
    if is_public?(object) do
      Object.increase_replies_count(reply_ap_id)
    end
  end

  def increase_replies_count_if_reply(_create_data), do: :noop

  def decrease_replies_count_if_reply(%Object{
        data: %{"inReplyTo" => reply_ap_id} = object
      }) do
    if is_public?(object) do
      Object.decrease_replies_count(reply_ap_id)
    end
  end

  def decrease_replies_count_if_reply(_object), do: :noop

  def increase_poll_votes_if_vote(%{
        "object" => %{"inReplyTo" => reply_ap_id, "name" => name},
        "type" => "Create"
      }) do
    Object.increase_vote_count(reply_ap_id, name)
  end

  def increase_poll_votes_if_vote(_create_data), do: :noop

  def insert(map, local \\ true, fake \\ false, bypass_actor_check \\ false) when is_map(map) do
    with nil <- Activity.normalize(map),
         map <- lazy_put_activity_defaults(map, fake),
         true <- bypass_actor_check || check_actor_is_active(map["actor"]),
         {_, true} <- {:remote_limit_error, check_remote_limit(map)},
         {:ok, map} <- MRF.filter(map),
         {recipients, _, _} = get_recipients(map),
         {:fake, false, map, recipients} <- {:fake, fake, map, recipients},
         {:containment, :ok} <- {:containment, Containment.contain_child(map)},
         {:ok, map, object} <- insert_full_object(map) do
      {:ok, activity} =
        Repo.insert(%Activity{
          data: map,
          local: local,
          actor: map["actor"],
          recipients: recipients
        })

      # Splice in the child object if we have one.
      activity =
        if not is_nil(object) do
          Map.put(activity, :object, object)
        else
          activity
        end

      BackgroundWorker.enqueue("fetch_data_for_activity", %{"activity_id" => activity.id})

      Notification.create_notifications(activity)

      conversation = create_or_bump_conversation(activity, map["actor"])
      participations = get_participations(conversation)
      stream_out(activity)
      stream_out_participations(participations)
      {:ok, activity}
    else
      %Activity{} = activity ->
        {:ok, activity}

      {:fake, true, map, recipients} ->
        activity = %Activity{
          data: map,
          local: local,
          actor: map["actor"],
          recipients: recipients,
          id: "pleroma:fakeid"
        }

        Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity)
        {:ok, activity}

      error ->
        {:error, error}
    end
  end

  defp create_or_bump_conversation(activity, actor) do
    with {:ok, conversation} <- Conversation.create_or_bump_for(activity),
         %User{} = user <- User.get_cached_by_ap_id(actor),
         Participation.mark_as_read(user, conversation) do
      {:ok, conversation}
    end
  end

  defp get_participations({:ok, conversation}) do
    conversation
    |> Repo.preload(:participations, force: true)
    |> Map.get(:participations)
  end

  defp get_participations(_), do: []

  def stream_out_participations(participations) do
    participations =
      participations
      |> Repo.preload(:user)

    Streamer.stream("participation", participations)
  end

  def stream_out_participations(%Object{data: %{"context" => context}}, user) do
    with %Conversation{} = conversation <- Conversation.get_for_ap_id(context),
         conversation = Repo.preload(conversation, :participations),
         last_activity_id =
           fetch_latest_activity_id_for_context(conversation.ap_id, %{
             "user" => user,
             "blocking_user" => user
           }) do
      if last_activity_id do
        stream_out_participations(conversation.participations)
      end
    end
  end

  def stream_out_participations(_, _), do: :noop

  def stream_out(%Activity{data: %{"type" => data_type}} = activity)
      when data_type in ["Create", "Announce", "Delete"] do
    activity
    |> Topics.get_activity_topics()
    |> Streamer.stream(activity)
  end

  def stream_out(_activity) do
    :noop
  end

  def create(%{to: to, actor: actor, context: context, object: object} = params, fake \\ false) do
    additional = params[:additional] || %{}
    # only accept false as false value
    local = !(params[:local] == false)
    published = params[:published]
    quick_insert? = Pleroma.Config.get([:env]) == :benchmark

    with create_data <-
           make_create_data(
             %{to: to, actor: actor, published: published, context: context, object: object},
             additional
           ),
         {:ok, activity} <- insert(create_data, local, fake),
         {:fake, false, activity} <- {:fake, fake, activity},
         _ <- increase_replies_count_if_reply(create_data),
         _ <- increase_poll_votes_if_vote(create_data),
         {:quick_insert, false, activity} <- {:quick_insert, quick_insert?, activity},
         {:ok, _actor} <- increase_note_count_if_public(actor, activity),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    else
      {:quick_insert, true, activity} ->
        {:ok, activity}

      {:fake, true, activity} ->
        {:ok, activity}

      {:error, message} ->
        {:error, message}
    end
  end

  def listen(%{to: to, actor: actor, context: context, object: object} = params) do
    additional = params[:additional] || %{}
    # only accept false as false value
    local = !(params[:local] == false)
    published = params[:published]

    with listen_data <-
           make_listen_data(
             %{to: to, actor: actor, published: published, context: context, object: object},
             additional
           ),
         {:ok, activity} <- insert(listen_data, local),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    else
      {:error, message} ->
        {:error, message}
    end
  end

  def accept(params) do
    accept_or_reject("Accept", params)
  end

  def reject(params) do
    accept_or_reject("Reject", params)
  end

  def accept_or_reject(type, %{to: to, actor: actor, object: object} = params) do
    local = Map.get(params, :local, true)
    activity_id = Map.get(params, :activity_id, nil)

    with data <-
           %{"to" => to, "type" => type, "actor" => actor.ap_id, "object" => object}
           |> Utils.maybe_put("id", activity_id),
         {:ok, activity} <- insert(data, local),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  def update(%{to: to, cc: cc, actor: actor, object: object} = params) do
    local = !(params[:local] == false)
    activity_id = params[:activity_id]

    with data <- %{
           "to" => to,
           "cc" => cc,
           "type" => "Update",
           "actor" => actor,
           "object" => object
         },
         data <- Utils.maybe_put(data, "id", activity_id),
         {:ok, activity} <- insert(data, local),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  def react_with_emoji(user, object, emoji, options \\ []) do
    with local <- Keyword.get(options, :local, true),
         activity_id <- Keyword.get(options, :activity_id, nil),
         Pleroma.Emoji.is_unicode_emoji?(emoji),
         reaction_data <- make_emoji_reaction_data(user, object, emoji, activity_id),
         {:ok, activity} <- insert(reaction_data, local),
         {:ok, object} <- add_emoji_reaction_to_object(activity, object),
         :ok <- maybe_federate(activity) do
      {:ok, activity, object}
    end
  end

  def unreact_with_emoji(user, reaction_id, options \\ []) do
    with local <- Keyword.get(options, :local, true),
         activity_id <- Keyword.get(options, :activity_id, nil),
         user_ap_id <- user.ap_id,
         %Activity{actor: ^user_ap_id} = reaction_activity <- Activity.get_by_ap_id(reaction_id),
         object <- Object.normalize(reaction_activity),
         unreact_data <- make_undo_data(user, reaction_activity, activity_id),
         {:ok, activity} <- insert(unreact_data, local),
         {:ok, object} <- remove_emoji_reaction_from_object(reaction_activity, object),
         :ok <- maybe_federate(activity) do
      {:ok, activity, object}
    end
  end

  # TODO: This is weird, maybe we shouldn't check here if we can make the activity.
  def like(
        %User{ap_id: ap_id} = user,
        %Object{data: %{"id" => _}} = object,
        activity_id \\ nil,
        local \\ true
      ) do
    with nil <- get_existing_like(ap_id, object),
         like_data <- make_like_data(user, object, activity_id),
         {:ok, activity} <- insert(like_data, local),
         {:ok, object} <- add_like_to_object(activity, object),
         :ok <- maybe_federate(activity) do
      {:ok, activity, object}
    else
      %Activity{} = activity -> {:ok, activity, object}
      error -> {:error, error}
    end
  end

  def unlike(%User{} = actor, %Object{} = object, activity_id \\ nil, local \\ true) do
    with %Activity{} = like_activity <- get_existing_like(actor.ap_id, object),
         unlike_data <- make_unlike_data(actor, like_activity, activity_id),
         {:ok, unlike_activity} <- insert(unlike_data, local),
         {:ok, _activity} <- Repo.delete(like_activity),
         {:ok, object} <- remove_like_from_object(like_activity, object),
         :ok <- maybe_federate(unlike_activity) do
      {:ok, unlike_activity, like_activity, object}
    else
      _e -> {:ok, object}
    end
  end

  def announce(
        %User{ap_id: _} = user,
        %Object{data: %{"id" => _}} = object,
        activity_id \\ nil,
        local \\ true,
        public \\ true
      ) do
    with true <- is_announceable?(object, user, public),
         announce_data <- make_announce_data(user, object, activity_id, public),
         {:ok, activity} <- insert(announce_data, local),
         {:ok, object} <- add_announce_to_object(activity, object),
         :ok <- maybe_federate(activity) do
      {:ok, activity, object}
    else
      error -> {:error, error}
    end
  end

  def unannounce(
        %User{} = actor,
        %Object{} = object,
        activity_id \\ nil,
        local \\ true
      ) do
    with %Activity{} = announce_activity <- get_existing_announce(actor.ap_id, object),
         unannounce_data <- make_unannounce_data(actor, announce_activity, activity_id),
         {:ok, unannounce_activity} <- insert(unannounce_data, local),
         :ok <- maybe_federate(unannounce_activity),
         {:ok, _activity} <- Repo.delete(announce_activity),
         {:ok, object} <- remove_announce_from_object(announce_activity, object) do
      {:ok, unannounce_activity, object}
    else
      _e -> {:ok, object}
    end
  end

  def follow(follower, followed, activity_id \\ nil, local \\ true) do
    with data <- make_follow_data(follower, followed, activity_id),
         {:ok, activity} <- insert(data, local),
         :ok <- maybe_federate(activity),
         _ <- User.set_follow_state_cache(follower.ap_id, followed.ap_id, activity.data["state"]) do
      {:ok, activity}
    end
  end

  def unfollow(follower, followed, activity_id \\ nil, local \\ true) do
    with %Activity{} = follow_activity <- fetch_latest_follow(follower, followed),
         {:ok, follow_activity} <- update_follow_state(follow_activity, "cancelled"),
         unfollow_data <- make_unfollow_data(follower, followed, follow_activity, activity_id),
         {:ok, activity} <- insert(unfollow_data, local),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  def delete(%User{ap_id: ap_id, follower_address: follower_address} = user) do
    with data <- %{
           "to" => [follower_address],
           "type" => "Delete",
           "actor" => ap_id,
           "object" => %{"type" => "Person", "id" => ap_id}
         },
         {:ok, activity} <- insert(data, true, true, true),
         :ok <- maybe_federate(activity) do
      {:ok, user}
    end
  end

  def delete(%Object{data: %{"id" => id, "actor" => actor}} = object, options \\ []) do
    local = Keyword.get(options, :local, true)
    activity_id = Keyword.get(options, :activity_id, nil)
    actor = Keyword.get(options, :actor, actor)

    user = User.get_cached_by_ap_id(actor)
    to = (object.data["to"] || []) ++ (object.data["cc"] || [])

    with create_activity <- Activity.get_create_by_object_ap_id(id),
         data <-
           %{
             "type" => "Delete",
             "actor" => actor,
             "object" => id,
             "to" => to,
             "deleted_activity_id" => create_activity && create_activity.id
           }
           |> maybe_put("id", activity_id),
         {:ok, activity} <- insert(data, local, false),
         {:ok, object, _create_activity} <- Object.delete(object),
         stream_out_participations(object, user),
         _ <- decrease_replies_count_if_reply(object),
         {:ok, _actor} <- decrease_note_count_if_public(user, object),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  @spec block(User.t(), User.t(), String.t() | nil, boolean) :: {:ok, Activity.t() | nil}
  def block(blocker, blocked, activity_id \\ nil, local \\ true) do
    outgoing_blocks = Config.get([:activitypub, :outgoing_blocks])
    unfollow_blocked = Config.get([:activitypub, :unfollow_blocked])

    if unfollow_blocked do
      follow_activity = fetch_latest_follow(blocker, blocked)
      if follow_activity, do: unfollow(blocker, blocked, nil, local)
    end

    with true <- outgoing_blocks,
         block_data <- make_block_data(blocker, blocked, activity_id),
         {:ok, activity} <- insert(block_data, local),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    else
      _e -> {:ok, nil}
    end
  end

  def unblock(blocker, blocked, activity_id \\ nil, local \\ true) do
    with %Activity{} = block_activity <- fetch_latest_block(blocker, blocked),
         unblock_data <- make_unblock_data(blocker, blocked, block_activity, activity_id),
         {:ok, activity} <- insert(unblock_data, local),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  @spec flag(map()) :: {:ok, Activity.t()} | any
  def flag(
        %{
          actor: actor,
          context: _context,
          account: account,
          statuses: statuses,
          content: content
        } = params
      ) do
    # only accept false as false value
    local = !(params[:local] == false)
    forward = !(params[:forward] == false)

    additional = params[:additional] || %{}

    additional =
      if forward do
        Map.merge(additional, %{"to" => [], "cc" => [account.ap_id]})
      else
        Map.merge(additional, %{"to" => [], "cc" => []})
      end

    with flag_data <- make_flag_data(params, additional),
         {:ok, activity} <- insert(flag_data, local),
         {:ok, stripped_activity} <- strip_report_status_data(activity),
         :ok <- maybe_federate(stripped_activity) do
      Enum.each(User.all_superusers(), fn superuser ->
        superuser
        |> Pleroma.Emails.AdminEmail.report(actor, account, statuses, content)
        |> Pleroma.Emails.Mailer.deliver_async()
      end)

      {:ok, activity}
    end
  end

  def move(%User{} = origin, %User{} = target, local \\ true) do
    params = %{
      "type" => "Move",
      "actor" => origin.ap_id,
      "object" => origin.ap_id,
      "target" => target.ap_id
    }

    with true <- origin.ap_id in target.also_known_as,
         {:ok, activity} <- insert(params, local) do
      maybe_federate(activity)

      BackgroundWorker.enqueue("move_following", %{
        "origin_id" => origin.id,
        "target_id" => target.id
      })

      {:ok, activity}
    else
      false -> {:error, "Target account must have the origin in `alsoKnownAs`"}
      err -> err
    end
  end

  defp fetch_activities_for_context_query(context, opts) do
    public = [Pleroma.Constants.as_public()]

    recipients =
      if opts["user"],
        do: [opts["user"].ap_id | User.following(opts["user"])] ++ public,
        else: public

    from(activity in Activity)
    |> maybe_preload_objects(opts)
    |> maybe_preload_bookmarks(opts)
    |> maybe_set_thread_muted_field(opts)
    |> restrict_blocked(opts)
    |> restrict_recipients(recipients, opts["user"])
    |> where(
      [activity],
      fragment(
        "?->>'type' = ? and ?->>'context' = ?",
        activity.data,
        "Create",
        activity.data,
        ^context
      )
    )
    |> exclude_poll_votes(opts)
    |> exclude_id(opts)
    |> order_by([activity], desc: activity.id)
  end

  @spec fetch_activities_for_context(String.t(), keyword() | map()) :: [Activity.t()]
  def fetch_activities_for_context(context, opts \\ %{}) do
    context
    |> fetch_activities_for_context_query(opts)
    |> Repo.all()
  end

  @spec fetch_latest_activity_id_for_context(String.t(), keyword() | map()) ::
          FlakeId.Ecto.CompatType.t() | nil
  def fetch_latest_activity_id_for_context(context, opts \\ %{}) do
    context
    |> fetch_activities_for_context_query(Map.merge(%{"skip_preload" => true}, opts))
    |> limit(1)
    |> select([a], a.id)
    |> Repo.one()
  end

  def fetch_public_activities(opts \\ %{}, pagination \\ :keyset) do
    opts = Map.drop(opts, ["user"])

    [Pleroma.Constants.as_public()]
    |> fetch_activities_query(opts)
    |> restrict_unlisted()
    |> Pagination.fetch_paginated(opts, pagination)
  end

  @valid_visibilities ~w[direct unlisted public private]

  defp restrict_visibility(query, %{visibility: visibility})
       when is_list(visibility) do
    if Enum.all?(visibility, &(&1 in @valid_visibilities)) do
      query =
        from(
          a in query,
          where:
            fragment(
              "activity_visibility(?, ?, ?) = ANY (?)",
              a.actor,
              a.recipients,
              a.data,
              ^visibility
            )
        )

      query
    else
      Logger.error("Could not restrict visibility to #{visibility}")
    end
  end

  defp restrict_visibility(query, %{visibility: visibility})
       when visibility in @valid_visibilities do
    from(
      a in query,
      where:
        fragment("activity_visibility(?, ?, ?) = ?", a.actor, a.recipients, a.data, ^visibility)
    )
  end

  defp restrict_visibility(_query, %{visibility: visibility})
       when visibility not in @valid_visibilities do
    Logger.error("Could not restrict visibility to #{visibility}")
  end

  defp restrict_visibility(query, _visibility), do: query

  defp exclude_visibility(query, %{"exclude_visibilities" => visibility})
       when is_list(visibility) do
    if Enum.all?(visibility, &(&1 in @valid_visibilities)) do
      from(
        a in query,
        where:
          not fragment(
            "activity_visibility(?, ?, ?) = ANY (?)",
            a.actor,
            a.recipients,
            a.data,
            ^visibility
          )
      )
    else
      Logger.error("Could not exclude visibility to #{visibility}")
      query
    end
  end

  defp exclude_visibility(query, %{"exclude_visibilities" => visibility})
       when visibility in @valid_visibilities do
    from(
      a in query,
      where:
        not fragment(
          "activity_visibility(?, ?, ?) = ?",
          a.actor,
          a.recipients,
          a.data,
          ^visibility
        )
    )
  end

  defp exclude_visibility(query, %{"exclude_visibilities" => visibility})
       when visibility not in @valid_visibilities do
    Logger.error("Could not exclude visibility to #{visibility}")
    query
  end

  defp exclude_visibility(query, _visibility), do: query

  defp restrict_thread_visibility(query, _, %{skip_thread_containment: true} = _),
    do: query

  defp restrict_thread_visibility(
         query,
         %{"user" => %User{skip_thread_containment: true}},
         _
       ),
       do: query

  defp restrict_thread_visibility(query, %{"user" => %User{ap_id: ap_id}}, _) do
    from(
      a in query,
      where: fragment("thread_visibility(?, (?)->>'id') = true", ^ap_id, a.data)
    )
  end

  defp restrict_thread_visibility(query, _, _), do: query

  def fetch_user_abstract_activities(user, reading_user, params \\ %{}) do
    params =
      params
      |> Map.put("user", reading_user)
      |> Map.put("actor_id", user.ap_id)
      |> Map.put("whole_db", true)

    recipients =
      user_activities_recipients(%{
        "godmode" => params["godmode"],
        "reading_user" => reading_user
      })

    fetch_activities(recipients, params)
    |> Enum.reverse()
  end

  def fetch_user_activities(user, reading_user, params \\ %{}) do
    params =
      params
      |> Map.put("type", ["Create", "Announce"])
      |> Map.put("user", reading_user)
      |> Map.put("actor_id", user.ap_id)
      |> Map.put("whole_db", true)
      |> Map.put("pinned_activity_ids", user.pinned_activities)

    params =
      if User.blocks?(reading_user, user) do
        params
      else
        params
        |> Map.put("blocking_user", reading_user)
        |> Map.put("muting_user", reading_user)
      end

    recipients =
      user_activities_recipients(%{
        "godmode" => params["godmode"],
        "reading_user" => reading_user
      })

    fetch_activities(recipients, params)
    |> Enum.reverse()
  end

  def fetch_instance_activities(params) do
    params =
      params
      |> Map.put("type", ["Create", "Announce"])
      |> Map.put("instance", params["instance"])
      |> Map.put("whole_db", true)

    fetch_activities([Pleroma.Constants.as_public()], params, :offset)
    |> Enum.reverse()
  end

  defp user_activities_recipients(%{"godmode" => true}) do
    []
  end

  defp user_activities_recipients(%{"reading_user" => reading_user}) do
    if reading_user do
      [Pleroma.Constants.as_public()] ++ [reading_user.ap_id | User.following(reading_user)]
    else
      [Pleroma.Constants.as_public()]
    end
  end

  defp restrict_since(query, %{"since_id" => ""}), do: query

  defp restrict_since(query, %{"since_id" => since_id}) do
    from(activity in query, where: activity.id > ^since_id)
  end

  defp restrict_since(query, _), do: query

  defp restrict_tag_reject(_query, %{"tag_reject" => _tag_reject, "skip_preload" => true}) do
    raise "Can't use the child object without preloading!"
  end

  defp restrict_tag_reject(query, %{"tag_reject" => tag_reject})
       when is_list(tag_reject) and tag_reject != [] do
    from(
      [_activity, object] in query,
      where: fragment("not (?)->'tag' \\?| (?)", object.data, ^tag_reject)
    )
  end

  defp restrict_tag_reject(query, _), do: query

  defp restrict_tag_all(_query, %{"tag_all" => _tag_all, "skip_preload" => true}) do
    raise "Can't use the child object without preloading!"
  end

  defp restrict_tag_all(query, %{"tag_all" => tag_all})
       when is_list(tag_all) and tag_all != [] do
    from(
      [_activity, object] in query,
      where: fragment("(?)->'tag' \\?& (?)", object.data, ^tag_all)
    )
  end

  defp restrict_tag_all(query, _), do: query

  defp restrict_tag(_query, %{"tag" => _tag, "skip_preload" => true}) do
    raise "Can't use the child object without preloading!"
  end

  defp restrict_tag(query, %{"tag" => tag}) when is_list(tag) do
    from(
      [_activity, object] in query,
      where: fragment("(?)->'tag' \\?| (?)", object.data, ^tag)
    )
  end

  defp restrict_tag(query, %{"tag" => tag}) when is_binary(tag) do
    from(
      [_activity, object] in query,
      where: fragment("(?)->'tag' \\? (?)", object.data, ^tag)
    )
  end

  defp restrict_tag(query, _), do: query

  defp restrict_recipients(query, [], _user), do: query

  defp restrict_recipients(query, recipients, nil) do
    from(activity in query, where: fragment("? && ?", ^recipients, activity.recipients))
  end

  defp restrict_recipients(query, recipients, user) do
    from(
      activity in query,
      where: fragment("? && ?", ^recipients, activity.recipients),
      or_where: activity.actor == ^user.ap_id
    )
  end

  defp restrict_local(query, %{"local_only" => true}) do
    from(activity in query, where: activity.local == true)
  end

  defp restrict_local(query, _), do: query

  defp restrict_actor(query, %{"actor_id" => actor_id}) do
    from(activity in query, where: activity.actor == ^actor_id)
  end

  defp restrict_actor(query, _), do: query

  defp restrict_type(query, %{"type" => type}) when is_binary(type) do
    from(activity in query, where: fragment("?->>'type' = ?", activity.data, ^type))
  end

  defp restrict_type(query, %{"type" => type}) do
    from(activity in query, where: fragment("?->>'type' = ANY(?)", activity.data, ^type))
  end

  defp restrict_type(query, _), do: query

  defp restrict_state(query, %{"state" => state}) do
    from(activity in query, where: fragment("?->>'state' = ?", activity.data, ^state))
  end

  defp restrict_state(query, _), do: query

  defp restrict_favorited_by(query, %{"favorited_by" => ap_id}) do
    from(
      [_activity, object] in query,
      where: fragment("(?)->'likes' \\? (?)", object.data, ^ap_id)
    )
  end

  defp restrict_favorited_by(query, _), do: query

  defp restrict_media(_query, %{"only_media" => _val, "skip_preload" => true}) do
    raise "Can't use the child object without preloading!"
  end

  defp restrict_media(query, %{"only_media" => val}) when val == "true" or val == "1" do
    from(
      [_activity, object] in query,
      where: fragment("not (?)->'attachment' = (?)", object.data, ^[])
    )
  end

  defp restrict_media(query, _), do: query

  defp restrict_replies(query, %{"exclude_replies" => val}) when val == "true" or val == "1" do
    from(
      [_activity, object] in query,
      where: fragment("?->>'inReplyTo' is null", object.data)
    )
  end

  defp restrict_replies(query, _), do: query

  defp restrict_reblogs(query, %{"exclude_reblogs" => val}) when val == "true" or val == "1" do
    from(activity in query, where: fragment("?->>'type' != 'Announce'", activity.data))
  end

  defp restrict_reblogs(query, _), do: query

  defp restrict_muted(query, %{"with_muted" => val}) when val in [true, "true", "1"], do: query

  defp restrict_muted(query, %{"muting_user" => %User{} = user} = opts) do
    mutes = opts["muted_users_ap_ids"] || User.muted_users_ap_ids(user)

    query =
      from([activity] in query,
        where: fragment("not (? = ANY(?))", activity.actor, ^mutes),
        where: fragment("not (?->'to' \\?| ?)", activity.data, ^mutes)
      )

    unless opts["skip_preload"] do
      from([thread_mute: tm] in query, where: is_nil(tm.user_id))
    else
      query
    end
  end

  defp restrict_muted(query, _), do: query

  defp restrict_blocked(query, %{"blocking_user" => %User{} = user} = opts) do
    blocked_ap_ids = opts["blocked_users_ap_ids"] || User.blocked_users_ap_ids(user)
    domain_blocks = user.domain_blocks || []

    query =
      if has_named_binding?(query, :object), do: query, else: Activity.with_joined_object(query)

    from(
      [activity, object: o] in query,
      where: fragment("not (? = ANY(?))", activity.actor, ^blocked_ap_ids),
      where: fragment("not (? && ?)", activity.recipients, ^blocked_ap_ids),
      where:
        fragment(
          "not (?->>'type' = 'Announce' and ?->'to' \\?| ?)",
          activity.data,
          activity.data,
          ^blocked_ap_ids
        ),
      where: fragment("not (split_part(?, '/', 3) = ANY(?))", activity.actor, ^domain_blocks),
      where: fragment("not (split_part(?->>'actor', '/', 3) = ANY(?))", o.data, ^domain_blocks)
    )
  end

  defp restrict_blocked(query, _), do: query

  defp restrict_unlisted(query) do
    from(
      activity in query,
      where:
        fragment(
          "not (coalesce(?->'cc', '{}'::jsonb) \\?| ?)",
          activity.data,
          ^[Pleroma.Constants.as_public()]
        )
    )
  end

  defp restrict_pinned(query, %{"pinned" => "true", "pinned_activity_ids" => ids}) do
    from(activity in query, where: activity.id in ^ids)
  end

  defp restrict_pinned(query, _), do: query

  defp restrict_muted_reblogs(query, %{"muting_user" => %User{} = user} = opts) do
    muted_reblogs = opts["reblog_muted_users_ap_ids"] || User.reblog_muted_users_ap_ids(user)

    from(
      activity in query,
      where:
        fragment(
          "not ( ?->>'type' = 'Announce' and ? = ANY(?))",
          activity.data,
          activity.actor,
          ^muted_reblogs
        )
    )
  end

  defp restrict_muted_reblogs(query, _), do: query

  defp restrict_instance(query, %{"instance" => instance}) do
    users =
      from(
        u in User,
        select: u.ap_id,
        where: fragment("? LIKE ?", u.nickname, ^"%@#{instance}")
      )
      |> Repo.all()

    from(activity in query, where: activity.actor in ^users)
  end

  defp restrict_instance(query, _), do: query

  defp exclude_poll_votes(query, %{"include_poll_votes" => true}), do: query

  defp exclude_poll_votes(query, _) do
    if has_named_binding?(query, :object) do
      from([activity, object: o] in query,
        where: fragment("not(?->>'type' = ?)", o.data, "Answer")
      )
    else
      query
    end
  end

  defp exclude_id(query, %{"exclude_id" => id}) when is_binary(id) do
    from(activity in query, where: activity.id != ^id)
  end

  defp exclude_id(query, _), do: query

  defp maybe_preload_objects(query, %{"skip_preload" => true}), do: query

  defp maybe_preload_objects(query, _) do
    query
    |> Activity.with_preloaded_object()
  end

  defp maybe_preload_bookmarks(query, %{"skip_preload" => true}), do: query

  defp maybe_preload_bookmarks(query, opts) do
    query
    |> Activity.with_preloaded_bookmark(opts["user"])
  end

  defp maybe_set_thread_muted_field(query, %{"skip_preload" => true}), do: query

  defp maybe_set_thread_muted_field(query, opts) do
    query
    |> Activity.with_set_thread_muted_field(opts["muting_user"] || opts["user"])
  end

  defp maybe_order(query, %{order: :desc}) do
    query
    |> order_by(desc: :id)
  end

  defp maybe_order(query, %{order: :asc}) do
    query
    |> order_by(asc: :id)
  end

  defp maybe_order(query, _), do: query

  defp fetch_activities_query_ap_ids_ops(opts) do
    source_user = opts["muting_user"]
    ap_id_relations = if source_user, do: [:mute, :reblog_mute], else: []

    ap_id_relations =
      ap_id_relations ++
        if opts["blocking_user"] && opts["blocking_user"] == source_user do
          [:block]
        else
          []
        end

    preloaded_ap_ids = User.outgoing_relations_ap_ids(source_user, ap_id_relations)

    restrict_blocked_opts = Map.merge(%{"blocked_users_ap_ids" => preloaded_ap_ids[:block]}, opts)
    restrict_muted_opts = Map.merge(%{"muted_users_ap_ids" => preloaded_ap_ids[:mute]}, opts)

    restrict_muted_reblogs_opts =
      Map.merge(%{"reblog_muted_users_ap_ids" => preloaded_ap_ids[:reblog_mute]}, opts)

    {restrict_blocked_opts, restrict_muted_opts, restrict_muted_reblogs_opts}
  end

  def fetch_activities_query(recipients, opts \\ %{}) do
    {restrict_blocked_opts, restrict_muted_opts, restrict_muted_reblogs_opts} =
      fetch_activities_query_ap_ids_ops(opts)

    config = %{
      skip_thread_containment: Config.get([:instance, :skip_thread_containment])
    }

    Activity
    |> maybe_preload_objects(opts)
    |> maybe_preload_bookmarks(opts)
    |> maybe_set_thread_muted_field(opts)
    |> maybe_order(opts)
    |> restrict_recipients(recipients, opts["user"])
    |> restrict_tag(opts)
    |> restrict_tag_reject(opts)
    |> restrict_tag_all(opts)
    |> restrict_since(opts)
    |> restrict_local(opts)
    |> restrict_actor(opts)
    |> restrict_type(opts)
    |> restrict_state(opts)
    |> restrict_favorited_by(opts)
    |> restrict_blocked(restrict_blocked_opts)
    |> restrict_muted(restrict_muted_opts)
    |> restrict_media(opts)
    |> restrict_visibility(opts)
    |> restrict_thread_visibility(opts, config)
    |> restrict_replies(opts)
    |> restrict_reblogs(opts)
    |> restrict_pinned(opts)
    |> restrict_muted_reblogs(restrict_muted_reblogs_opts)
    |> restrict_instance(opts)
    |> Activity.restrict_deactivated_users()
    |> exclude_poll_votes(opts)
    |> exclude_visibility(opts)
  end

  def fetch_activities(recipients, opts \\ %{}, pagination \\ :keyset) do
    list_memberships = Pleroma.List.memberships(opts["user"])

    fetch_activities_query(recipients ++ list_memberships, opts)
    |> Pagination.fetch_paginated(opts, pagination)
    |> Enum.reverse()
    |> maybe_update_cc(list_memberships, opts["user"])
  end

  defp maybe_update_cc(activities, list_memberships, %User{ap_id: user_ap_id})
       when is_list(list_memberships) and length(list_memberships) > 0 do
    Enum.map(activities, fn
      %{data: %{"bcc" => bcc}} = activity when is_list(bcc) and length(bcc) > 0 ->
        if Enum.any?(bcc, &(&1 in list_memberships)) do
          update_in(activity.data["cc"], &[user_ap_id | &1])
        else
          activity
        end

      activity ->
        activity
    end)
  end

  defp maybe_update_cc(activities, _, _), do: activities

  def fetch_activities_bounded_query(query, recipients, recipients_with_public) do
    from(activity in query,
      where:
        fragment("? && ?", activity.recipients, ^recipients) or
          (fragment("? && ?", activity.recipients, ^recipients_with_public) and
             ^Pleroma.Constants.as_public() in activity.recipients)
    )
  end

  def fetch_activities_bounded(
        recipients,
        recipients_with_public,
        opts \\ %{},
        pagination \\ :keyset
      ) do
    fetch_activities_query([], opts)
    |> fetch_activities_bounded_query(recipients, recipients_with_public)
    |> Pagination.fetch_paginated(opts, pagination)
    |> Enum.reverse()
  end

  def upload(file, opts \\ []) do
    with {:ok, data} <- Upload.store(file, opts) do
      obj_data =
        if opts[:actor] do
          Map.put(data, "actor", opts[:actor])
        else
          data
        end

      Repo.insert(%Object{data: obj_data})
    end
  end

  defp object_to_user_data(data) do
    avatar =
      data["icon"]["url"] &&
        %{
          "type" => "Image",
          "url" => [%{"href" => data["icon"]["url"]}]
        }

    banner =
      data["image"]["url"] &&
        %{
          "type" => "Image",
          "url" => [%{"href" => data["image"]["url"]}]
        }

    fields =
      data
      |> Map.get("attachment", [])
      |> Enum.filter(fn %{"type" => t} -> t == "PropertyValue" end)
      |> Enum.map(fn fields -> Map.take(fields, ["name", "value"]) end)

    locked = data["manuallyApprovesFollowers"] || false
    data = Transmogrifier.maybe_fix_user_object(data)
    discoverable = data["discoverable"] || false
    invisible = data["invisible"] || false
    actor_type = data["type"] || "Person"

    user_data = %{
      ap_id: data["id"],
      ap_enabled: true,
      source_data: data,
      banner: banner,
      fields: fields,
      locked: locked,
      discoverable: discoverable,
      invisible: invisible,
      avatar: avatar,
      name: data["name"],
      follower_address: data["followers"],
      following_address: data["following"],
      bio: data["summary"],
      actor_type: actor_type,
      also_known_as: Map.get(data, "alsoKnownAs", [])
    }

    # nickname can be nil because of virtual actors
    user_data =
      if data["preferredUsername"] do
        Map.put(
          user_data,
          :nickname,
          "#{data["preferredUsername"]}@#{URI.parse(data["id"]).host}"
        )
      else
        Map.put(user_data, :nickname, nil)
      end

    {:ok, user_data}
  end

  def fetch_follow_information_for_user(user) do
    with {:ok, following_data} <-
           Fetcher.fetch_and_contain_remote_object_from_id(user.following_address),
         following_count when is_integer(following_count) <- following_data["totalItems"],
         {:ok, hide_follows} <- collection_private(following_data),
         {:ok, followers_data} <-
           Fetcher.fetch_and_contain_remote_object_from_id(user.follower_address),
         followers_count when is_integer(followers_count) <- followers_data["totalItems"],
         {:ok, hide_followers} <- collection_private(followers_data) do
      {:ok,
       %{
         hide_follows: hide_follows,
         follower_count: followers_count,
         following_count: following_count,
         hide_followers: hide_followers
       }}
    else
      {:error, _} = e ->
        e

      e ->
        {:error, e}
    end
  end

  defp maybe_update_follow_information(data) do
    with {:enabled, true} <-
           {:enabled, Pleroma.Config.get([:instance, :external_user_synchronization])},
         {:ok, info} <- fetch_follow_information_for_user(data) do
      info = Map.merge(data[:info] || %{}, info)
      Map.put(data, :info, info)
    else
      {:enabled, false} ->
        data

      e ->
        Logger.error(
          "Follower/Following counter update for #{data.ap_id} failed.\n" <> inspect(e)
        )

        data
    end
  end

  defp collection_private(%{"first" => first}) do
    if is_map(first) and
         first["type"] in ["CollectionPage", "OrderedCollectionPage"] do
      {:ok, false}
    else
      with {:ok, %{"type" => type}} when type in ["CollectionPage", "OrderedCollectionPage"] <-
             Fetcher.fetch_and_contain_remote_object_from_id(first) do
        {:ok, false}
      else
        {:error, {:ok, %{status: code}}} when code in [401, 403] ->
          {:ok, true}

        {:error, _} = e ->
          e

        e ->
          {:error, e}
      end
    end
  end

  defp collection_private(_data), do: {:ok, true}

  def user_data_from_user_object(data) do
    with {:ok, data} <- MRF.filter(data),
         {:ok, data} <- object_to_user_data(data) do
      {:ok, data}
    else
      e -> {:error, e}
    end
  end

  def fetch_and_prepare_user_from_ap_id(ap_id) do
    with {:ok, data} <- Fetcher.fetch_and_contain_remote_object_from_id(ap_id),
         {:ok, data} <- user_data_from_user_object(data),
         data <- maybe_update_follow_information(data) do
      {:ok, data}
    else
      e ->
        Logger.error("Could not decode user at fetch #{ap_id}, #{inspect(e)}")
        {:error, e}
    end
  end

  def make_user_from_ap_id(ap_id) do
    if _user = User.get_cached_by_ap_id(ap_id) do
      Transmogrifier.upgrade_user_from_ap_id(ap_id)
    else
      with {:ok, data} <- fetch_and_prepare_user_from_ap_id(ap_id) do
        User.insert_or_update_user(data)
      else
        e -> {:error, e}
      end
    end
  end

  def make_user_from_nickname(nickname) do
    with {:ok, %{"ap_id" => ap_id}} when not is_nil(ap_id) <- WebFinger.finger(nickname) do
      make_user_from_ap_id(ap_id)
    else
      _e -> {:error, "No AP id in WebFinger"}
    end
  end

  # filter out broken threads
  def contain_broken_threads(%Activity{} = activity, %User{} = user) do
    entire_thread_visible_for_user?(activity, user)
  end

  # do post-processing on a specific activity
  def contain_activity(%Activity{} = activity, %User{} = user) do
    contain_broken_threads(activity, user)
  end

  def fetch_direct_messages_query do
    Activity
    |> restrict_type(%{"type" => "Create"})
    |> restrict_visibility(%{visibility: "direct"})
    |> order_by([activity], asc: activity.id)
  end
end
