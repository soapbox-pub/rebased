# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ActivityPub do
  alias Pleroma.Activity
  alias Pleroma.Instances
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Upload
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.MRF
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.Federator
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.WebFinger

  import Ecto.Query
  import Pleroma.Web.ActivityPub.Utils
  import Pleroma.Web.ActivityPub.Visibility

  require Logger

  @httpoison Application.get_env(:pleroma, :httpoison)

  # For Announce activities, we filter the recipients based on following status for any actors
  # that match actual users.  See issue #164 for more information about why this is necessary.
  defp get_recipients(%{"type" => "Announce"} = data) do
    to = data["to"] || []
    cc = data["cc"] || []
    actor = User.get_cached_by_ap_id(data["actor"])

    recipients =
      (to ++ cc)
      |> Enum.filter(fn recipient ->
        case User.get_cached_by_ap_id(recipient) do
          nil ->
            true

          user ->
            User.following?(user, actor)
        end
      end)

    {recipients, to, cc}
  end

  defp get_recipients(%{"type" => "Create"} = data) do
    to = data["to"] || []
    cc = data["cc"] || []
    actor = data["actor"] || []
    recipients = (to ++ cc ++ [actor]) |> Enum.uniq()
    {recipients, to, cc}
  end

  defp get_recipients(data) do
    to = data["to"] || []
    cc = data["cc"] || []
    recipients = to ++ cc
    {recipients, to, cc}
  end

  defp check_actor_is_active(actor) do
    if not is_nil(actor) do
      with user <- User.get_cached_by_ap_id(actor),
           false <- user.info.deactivated do
        :ok
      else
        _e -> :reject
      end
    else
      :ok
    end
  end

  defp check_remote_limit(%{"object" => %{"content" => content}}) when not is_nil(content) do
    limit = Pleroma.Config.get([:instance, :remote_limit])
    String.length(content) <= limit
  end

  defp check_remote_limit(_), do: true

  def increase_note_count_if_public(actor, object) do
    if is_public?(object), do: User.increase_note_count(actor), else: {:ok, actor}
  end

  def decrease_note_count_if_public(actor, object) do
    if is_public?(object), do: User.decrease_note_count(actor), else: {:ok, actor}
  end

  def insert(map, local \\ true) when is_map(map) do
    with nil <- Activity.normalize(map),
         map <- lazy_put_activity_defaults(map),
         :ok <- check_actor_is_active(map["actor"]),
         {_, true} <- {:remote_limit_error, check_remote_limit(map)},
         {:ok, map} <- MRF.filter(map),
         :ok <- insert_full_object(map) do
      {recipients, _, _} = get_recipients(map)

      {:ok, activity} =
        Repo.insert(%Activity{
          data: map,
          local: local,
          actor: map["actor"],
          recipients: recipients
        })

      Task.start(fn ->
        Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity)
      end)

      Notification.create_notifications(activity)
      stream_out(activity)
      {:ok, activity}
    else
      %Activity{} = activity -> {:ok, activity}
      error -> {:error, error}
    end
  end

  def stream_out(activity) do
    public = "https://www.w3.org/ns/activitystreams#Public"

    if activity.data["type"] in ["Create", "Announce", "Delete"] do
      Pleroma.Web.Streamer.stream("user", activity)
      Pleroma.Web.Streamer.stream("list", activity)

      if Enum.member?(activity.data["to"], public) do
        Pleroma.Web.Streamer.stream("public", activity)

        if activity.local do
          Pleroma.Web.Streamer.stream("public:local", activity)
        end

        if activity.data["type"] in ["Create"] do
          activity.data["object"]
          |> Map.get("tag", [])
          |> Enum.filter(fn tag -> is_bitstring(tag) end)
          |> Enum.each(fn tag -> Pleroma.Web.Streamer.stream("hashtag:" <> tag, activity) end)

          if activity.data["object"]["attachment"] != [] do
            Pleroma.Web.Streamer.stream("public:media", activity)

            if activity.local do
              Pleroma.Web.Streamer.stream("public:local:media", activity)
            end
          end
        end
      else
        if !Enum.member?(activity.data["cc"] || [], public) &&
             !Enum.member?(
               activity.data["to"],
               User.get_by_ap_id(activity.data["actor"]).follower_address
             ),
           do: Pleroma.Web.Streamer.stream("direct", activity)
      end
    end
  end

  def create(%{to: to, actor: actor, context: context, object: object} = params) do
    additional = params[:additional] || %{}
    # only accept false as false value
    local = !(params[:local] == false)
    published = params[:published]

    with create_data <-
           make_create_data(
             %{to: to, actor: actor, published: published, context: context, object: object},
             additional
           ),
         {:ok, activity} <- insert(create_data, local),
         # Changing note count prior to enqueuing federation task in order to avoid
         # race conditions on updating user.info
         {:ok, _actor} <- increase_note_count_if_public(actor, activity),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  def accept(%{to: to, actor: actor, object: object} = params) do
    # only accept false as false value
    local = !(params[:local] == false)

    with data <- %{"to" => to, "type" => "Accept", "actor" => actor.ap_id, "object" => object},
         {:ok, activity} <- insert(data, local),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  def reject(%{to: to, actor: actor, object: object} = params) do
    # only accept false as false value
    local = !(params[:local] == false)

    with data <- %{"to" => to, "type" => "Reject", "actor" => actor.ap_id, "object" => object},
         {:ok, activity} <- insert(data, local),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  def update(%{to: to, cc: cc, actor: actor, object: object} = params) do
    # only accept false as false value
    local = !(params[:local] == false)

    with data <- %{
           "to" => to,
           "cc" => cc,
           "type" => "Update",
           "actor" => actor,
           "object" => object
         },
         {:ok, activity} <- insert(data, local),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
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

  def unlike(
        %User{} = actor,
        %Object{} = object,
        activity_id \\ nil,
        local \\ true
      ) do
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
    with true <- is_public?(object),
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
         :ok <- maybe_federate(activity) do
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

  def delete(%Object{data: %{"id" => id, "actor" => actor}} = object, local \\ true) do
    user = User.get_cached_by_ap_id(actor)
    to = object.data["to"] || [] ++ object.data["cc"] || []

    with {:ok, object, activity} <- Object.delete(object),
         data <- %{
           "type" => "Delete",
           "actor" => actor,
           "object" => id,
           "to" => to,
           "deleted_activity_id" => activity && activity.id
         },
         {:ok, activity} <- insert(data, local),
         # Changing note count prior to enqueuing federation task in order to avoid
         # race conditions on updating user.info
         {:ok, _actor} <- decrease_note_count_if_public(user, object),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  def block(blocker, blocked, activity_id \\ nil, local \\ true) do
    ap_config = Application.get_env(:pleroma, :activitypub)
    unfollow_blocked = Keyword.get(ap_config, :unfollow_blocked)
    outgoing_blocks = Keyword.get(ap_config, :outgoing_blocks)

    with true <- unfollow_blocked do
      follow_activity = fetch_latest_follow(blocker, blocked)

      if follow_activity do
        unfollow(blocker, blocked, nil, local)
      end
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

  def flag(
        %{
          actor: actor,
          context: context,
          account: account,
          statuses: statuses,
          content: content
        } = params
      ) do
    additional = params[:additional] || %{}

    # only accept false as false value
    local = !(params[:local] == false)

    %{
      actor: actor,
      context: context,
      account: account,
      statuses: statuses,
      content: content
    }
    |> make_flag_data(additional)
    |> insert(local)
  end

  def fetch_activities_for_context(context, opts \\ %{}) do
    public = ["https://www.w3.org/ns/activitystreams#Public"]

    recipients =
      if opts["user"], do: [opts["user"].ap_id | opts["user"].following] ++ public, else: public

    query = from(activity in Activity)

    query =
      query
      |> restrict_blocked(opts)
      |> restrict_recipients(recipients, opts["user"])

    query =
      from(
        activity in query,
        where:
          fragment(
            "?->>'type' = ? and ?->>'context' = ?",
            activity.data,
            "Create",
            activity.data,
            ^context
          ),
        order_by: [desc: :id]
      )

    Repo.all(query)
  end

  def fetch_public_activities(opts \\ %{}) do
    q = fetch_activities_query(["https://www.w3.org/ns/activitystreams#Public"], opts)

    q
    |> restrict_unlisted()
    |> Repo.all()
    |> Enum.reverse()
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

      Ecto.Adapters.SQL.to_sql(:all, Repo, query)

      query
    else
      Logger.error("Could not restrict visibility to #{visibility}")
    end
  end

  defp restrict_visibility(query, %{visibility: visibility})
       when visibility in @valid_visibilities do
    query =
      from(
        a in query,
        where:
          fragment("activity_visibility(?, ?, ?) = ?", a.actor, a.recipients, a.data, ^visibility)
      )

    Ecto.Adapters.SQL.to_sql(:all, Repo, query)

    query
  end

  defp restrict_visibility(_query, %{visibility: visibility})
       when visibility not in @valid_visibilities do
    Logger.error("Could not restrict visibility to #{visibility}")
  end

  defp restrict_visibility(query, _visibility), do: query

  def fetch_user_activities(user, reading_user, params \\ %{}) do
    params =
      params
      |> Map.put("type", ["Create", "Announce"])
      |> Map.put("actor_id", user.ap_id)
      |> Map.put("whole_db", true)
      |> Map.put("pinned_activity_ids", user.info.pinned_activities)

    recipients =
      if reading_user do
        ["https://www.w3.org/ns/activitystreams#Public"] ++
          [reading_user.ap_id | reading_user.following]
      else
        ["https://www.w3.org/ns/activitystreams#Public"]
      end

    fetch_activities(recipients, params)
    |> Enum.reverse()
  end

  defp restrict_since(query, %{"since_id" => ""}), do: query

  defp restrict_since(query, %{"since_id" => since_id}) do
    from(activity in query, where: activity.id > ^since_id)
  end

  defp restrict_since(query, _), do: query

  defp restrict_tag_reject(query, %{"tag_reject" => tag_reject})
       when is_list(tag_reject) and tag_reject != [] do
    from(
      activity in query,
      where: fragment(~s(\(not \(? #> '{"object","tag"}'\) \\?| ?\)), activity.data, ^tag_reject)
    )
  end

  defp restrict_tag_reject(query, _), do: query

  defp restrict_tag_all(query, %{"tag_all" => tag_all})
       when is_list(tag_all) and tag_all != [] do
    from(
      activity in query,
      where: fragment(~s(\(? #> '{"object","tag"}'\) \\?& ?), activity.data, ^tag_all)
    )
  end

  defp restrict_tag_all(query, _), do: query

  defp restrict_tag(query, %{"tag" => tag}) when is_list(tag) do
    from(
      activity in query,
      where: fragment(~s(\(? #> '{"object","tag"}'\) \\?| ?), activity.data, ^tag)
    )
  end

  defp restrict_tag(query, %{"tag" => tag}) when is_binary(tag) do
    from(
      activity in query,
      where: fragment(~s(? <@ (? #> '{"object","tag"}'\)), ^tag, activity.data)
    )
  end

  defp restrict_tag(query, _), do: query

  defp restrict_to_cc(query, recipients_to, recipients_cc) do
    from(
      activity in query,
      where:
        fragment(
          "(?->'to' \\?| ?) or (?->'cc' \\?| ?)",
          activity.data,
          ^recipients_to,
          activity.data,
          ^recipients_cc
        )
    )
  end

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

  defp restrict_limit(query, %{"limit" => limit}) do
    from(activity in query, limit: ^limit)
  end

  defp restrict_limit(query, _), do: query

  defp restrict_local(query, %{"local_only" => true}) do
    from(activity in query, where: activity.local == true)
  end

  defp restrict_local(query, _), do: query

  defp restrict_max(query, %{"max_id" => ""}), do: query

  defp restrict_max(query, %{"max_id" => max_id}) do
    from(activity in query, where: activity.id < ^max_id)
  end

  defp restrict_max(query, _), do: query

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

  defp restrict_favorited_by(query, %{"favorited_by" => ap_id}) do
    from(
      activity in query,
      where: fragment(~s(? <@ (? #> '{"object","likes"}'\)), ^ap_id, activity.data)
    )
  end

  defp restrict_favorited_by(query, _), do: query

  defp restrict_media(query, %{"only_media" => val}) when val == "true" or val == "1" do
    from(
      activity in query,
      where: fragment(~s(not (? #> '{"object","attachment"}' = ?\)), activity.data, ^[])
    )
  end

  defp restrict_media(query, _), do: query

  defp restrict_replies(query, %{"exclude_replies" => val}) when val == "true" or val == "1" do
    from(
      activity in query,
      where: fragment("?->'object'->>'inReplyTo' is null", activity.data)
    )
  end

  defp restrict_replies(query, _), do: query

  defp restrict_reblogs(query, %{"exclude_reblogs" => val}) when val == "true" or val == "1" do
    from(activity in query, where: fragment("?->>'type' != 'Announce'", activity.data))
  end

  defp restrict_reblogs(query, _), do: query

  defp restrict_muted(query, %{"with_muted" => val}) when val in [true, "true", "1"], do: query

  defp restrict_muted(query, %{"muting_user" => %User{info: info}}) do
    mutes = info.mutes

    from(
      activity in query,
      where: fragment("not (? = ANY(?))", activity.actor, ^mutes),
      where: fragment("not (?->'to' \\?| ?)", activity.data, ^mutes)
    )
  end

  defp restrict_muted(query, _), do: query

  defp restrict_blocked(query, %{"blocking_user" => %User{info: info}}) do
    blocks = info.blocks || []
    domain_blocks = info.domain_blocks || []

    from(
      activity in query,
      where: fragment("not (? = ANY(?))", activity.actor, ^blocks),
      where: fragment("not (?->'to' \\?| ?)", activity.data, ^blocks),
      where: fragment("not (split_part(?, '/', 3) = ANY(?))", activity.actor, ^domain_blocks)
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
          ^["https://www.w3.org/ns/activitystreams#Public"]
        )
    )
  end

  defp restrict_pinned(query, %{"pinned" => "true", "pinned_activity_ids" => ids}) do
    from(activity in query, where: activity.id in ^ids)
  end

  defp restrict_pinned(query, _), do: query

  def fetch_activities_query(recipients, opts \\ %{}) do
    base_query =
      from(
        activity in Activity,
        limit: 20,
        order_by: [fragment("? desc nulls last", activity.id)]
      )

    base_query
    |> restrict_recipients(recipients, opts["user"])
    |> restrict_tag(opts)
    |> restrict_tag_reject(opts)
    |> restrict_tag_all(opts)
    |> restrict_since(opts)
    |> restrict_local(opts)
    |> restrict_limit(opts)
    |> restrict_max(opts)
    |> restrict_actor(opts)
    |> restrict_type(opts)
    |> restrict_favorited_by(opts)
    |> restrict_blocked(opts)
    |> restrict_muted(opts)
    |> restrict_media(opts)
    |> restrict_visibility(opts)
    |> restrict_replies(opts)
    |> restrict_reblogs(opts)
    |> restrict_pinned(opts)
  end

  def fetch_activities(recipients, opts \\ %{}) do
    fetch_activities_query(recipients, opts)
    |> Repo.all()
    |> Enum.reverse()
  end

  def fetch_activities_bounded(recipients_to, recipients_cc, opts \\ %{}) do
    fetch_activities_query([], opts)
    |> restrict_to_cc(recipients_to, recipients_cc)
    |> Repo.all()
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

  def user_data_from_user_object(data) do
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

    locked = data["manuallyApprovesFollowers"] || false
    data = Transmogrifier.maybe_fix_user_object(data)

    user_data = %{
      ap_id: data["id"],
      info: %{
        "ap_enabled" => true,
        "source_data" => data,
        "banner" => banner,
        "locked" => locked
      },
      avatar: avatar,
      name: data["name"],
      follower_address: data["followers"],
      bio: data["summary"]
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

  def fetch_and_prepare_user_from_ap_id(ap_id) do
    with {:ok, data} <- fetch_and_contain_remote_object_from_id(ap_id) do
      user_data_from_user_object(data)
    else
      e -> Logger.error("Could not decode user at fetch #{ap_id}, #{inspect(e)}")
    end
  end

  def make_user_from_ap_id(ap_id) do
    if _user = User.get_by_ap_id(ap_id) do
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

  def should_federate?(inbox, public) do
    if public do
      true
    else
      inbox_info = URI.parse(inbox)
      !Enum.member?(Pleroma.Config.get([:instance, :quarantined_instances], []), inbox_info.host)
    end
  end

  def publish(actor, activity) do
    remote_followers =
      if actor.follower_address in activity.recipients do
        {:ok, followers} = User.get_followers(actor)
        followers |> Enum.filter(&(!&1.local))
      else
        []
      end

    public = is_public?(activity)

    {:ok, data} = Transmogrifier.prepare_outgoing(activity.data)
    json = Jason.encode!(data)

    (Pleroma.Web.Salmon.remote_users(activity) ++ remote_followers)
    |> Enum.filter(fn user -> User.ap_enabled?(user) end)
    |> Enum.map(fn %{info: %{source_data: data}} ->
      (is_map(data["endpoints"]) && Map.get(data["endpoints"], "sharedInbox")) || data["inbox"]
    end)
    |> Enum.uniq()
    |> Enum.filter(fn inbox -> should_federate?(inbox, public) end)
    |> Instances.filter_reachable()
    |> Enum.each(fn {inbox, unreachable_since} ->
      Federator.publish_single_ap(%{
        inbox: inbox,
        json: json,
        actor: actor,
        id: activity.data["id"],
        unreachable_since: unreachable_since
      })
    end)
  end

  def publish_one(%{inbox: inbox, json: json, actor: actor, id: id} = params) do
    Logger.info("Federating #{id} to #{inbox}")
    host = URI.parse(inbox).host

    digest = "SHA-256=" <> (:crypto.hash(:sha256, json) |> Base.encode64())

    date =
      NaiveDateTime.utc_now()
      |> Timex.format!("{WDshort}, {0D} {Mshort} {YYYY} {h24}:{m}:{s} GMT")

    signature =
      Pleroma.Web.HTTPSignatures.sign(actor, %{
        host: host,
        "content-length": byte_size(json),
        digest: digest,
        date: date
      })

    with {:ok, %{status: code}} when code in 200..299 <-
           result =
             @httpoison.post(
               inbox,
               json,
               [
                 {"Content-Type", "application/activity+json"},
                 {"Date", date},
                 {"signature", signature},
                 {"digest", digest}
               ]
             ) do
      if !Map.has_key?(params, :unreachable_since) || params[:unreachable_since],
        do: Instances.set_reachable(inbox)

      result
    else
      {_post_result, response} ->
        unless params[:unreachable_since], do: Instances.set_unreachable(inbox)
        {:error, response}
    end
  end

  # TODO:
  # This will create a Create activity, which we need internally at the moment.
  def fetch_object_from_id(id) do
    if object = Object.get_cached_by_ap_id(id) do
      {:ok, object}
    else
      with {:ok, data} <- fetch_and_contain_remote_object_from_id(id),
           nil <- Object.normalize(data),
           params <- %{
             "type" => "Create",
             "to" => data["to"],
             "cc" => data["cc"],
             "actor" => data["actor"] || data["attributedTo"],
             "object" => data
           },
           :ok <- Transmogrifier.contain_origin(id, params),
           {:ok, activity} <- Transmogrifier.handle_incoming(params) do
        {:ok, Object.normalize(activity.data["object"])}
      else
        {:error, {:reject, nil}} ->
          {:reject, nil}

        object = %Object{} ->
          {:ok, object}

        _e ->
          Logger.info("Couldn't get object via AP, trying out OStatus fetching...")

          case OStatus.fetch_activity_from_url(id) do
            {:ok, [activity | _]} -> {:ok, Object.normalize(activity.data["object"])}
            e -> e
          end
      end
    end
  end

  def fetch_and_contain_remote_object_from_id(id) do
    Logger.info("Fetching object #{id} via AP")

    with true <- String.starts_with?(id, "http"),
         {:ok, %{body: body, status: code}} when code in 200..299 <-
           @httpoison.get(
             id,
             [{:Accept, "application/activity+json"}]
           ),
         {:ok, data} <- Jason.decode(body),
         :ok <- Transmogrifier.contain_origin_from_id(id, data) do
      {:ok, data}
    else
      e ->
        {:error, e}
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

  # do post-processing on a timeline
  def contain_timeline(timeline, user) do
    timeline
    |> Enum.filter(fn activity ->
      contain_activity(activity, user)
    end)
  end
end
