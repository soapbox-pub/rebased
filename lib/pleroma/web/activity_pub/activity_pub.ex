defmodule Pleroma.Web.ActivityPub.ActivityPub do
  alias Pleroma.{Activity, Repo, Object, Upload, User, Notification}
  alias Pleroma.Web.ActivityPub.{Transmogrifier, MRF}
  alias Pleroma.Web.WebFinger
  alias Pleroma.Web.Federator
  alias Pleroma.Web.OStatus
  import Ecto.Query
  import Pleroma.Web.ActivityPub.Utils
  require Logger

  @httpoison Application.get_env(:pleroma, :httpoison)

  @instance Application.get_env(:pleroma, :instance)

  def get_recipients(data) do
    (data["to"] || []) ++ (data["cc"] || [])
  end

  defp check_actor_is_active(actor) do
    if not is_nil(actor) do
      with user <- User.get_cached_by_ap_id(actor),
           nil <- user.info["deactivated"] do
        :ok
      else
        _e -> :reject
      end
    else
      :ok
    end
  end

  def insert(map, local \\ true) when is_map(map) do
    with nil <- Activity.get_by_ap_id(map["id"]),
         map <- lazy_put_activity_defaults(map),
         :ok <- check_actor_is_active(map["actor"]),
         {:ok, map} <- MRF.filter(map),
         :ok <- insert_full_object(map) do
      {:ok, activity} =
        Repo.insert(%Activity{
          data: map,
          local: local,
          actor: map["actor"],
          recipients: get_recipients(map)
        })

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

    if activity.data["type"] in ["Create", "Announce"] do
      Pleroma.Web.Streamer.stream("user", activity)

      if Enum.member?(activity.data["to"], public) do
        Pleroma.Web.Streamer.stream("public", activity)

        if activity.local do
          Pleroma.Web.Streamer.stream("public:local", activity)
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
         :ok <- maybe_federate(activity),
         {:ok, _actor} <- User.increase_note_count(actor) do
      {:ok, activity}
    end
  end

  def accept(%{to: to, actor: actor, object: object} = params) do
    # only accept false as false value
    local = !(params[:local] == false)

    with data <- %{"to" => to, "type" => "Accept", "actor" => actor, "object" => object},
         {:ok, activity} <- insert(data, local),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  def reject(%{to: to, actor: actor, object: object} = params) do
    # only accept false as false value
    local = !(params[:local] == false)

    with data <- %{"to" => to, "type" => "Reject", "actor" => actor, "object" => object},
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
        local \\ true
      ) do
    with true <- is_public?(object),
         announce_data <- make_announce_data(user, object, activity_id),
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
      {:ok, unannounce_activity, announce_activity, object}
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
         unfollow_data <- make_unfollow_data(follower, followed, follow_activity, activity_id),
         {:ok, activity} <- insert(unfollow_data, local),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  def delete(%Object{data: %{"id" => id, "actor" => actor}} = object, local \\ true) do
    user = User.get_cached_by_ap_id(actor)

    data = %{
      "type" => "Delete",
      "actor" => actor,
      "object" => id,
      "to" => [user.follower_address, "https://www.w3.org/ns/activitystreams#Public"]
    }

    with Repo.delete(object),
         Repo.delete_all(Activity.all_non_create_by_object_ap_id_q(id)),
         {:ok, activity} <- insert(data, local),
         :ok <- maybe_federate(activity),
         {:ok, _actor} <- User.decrease_note_count(user) do
      {:ok, activity}
    end
  end

  @ap_config Application.get_env(:pleroma, :activitypub)
  @unfollow_blocked Keyword.get(@ap_config, :unfollow_blocked)
  @outgoing_blocks Keyword.get(@ap_config, :outgoing_blocks)

  def block(blocker, blocked, activity_id \\ nil, local \\ true) do

    with true <- @unfollow_blocked do
      follow_activity = fetch_latest_follow(blocker, blocked)
      if follow_activity do
        unfollow(blocker, blocked, nil, local)
      end
    end

    with true <- @outgoing_blocks do
      with block_data <- make_block_data(blocker, blocked, activity_id),
           {:ok, activity} <- insert(block_data, local),
           :ok <- maybe_federate(activity) do
        {:ok, activity}
      end
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

  defp restrict_visibility(query, %{visibility: "direct"}) do
    public = "https://www.w3.org/ns/activitystreams#Public"

    from(
      activity in query,
      join: sender in User,
      on: sender.ap_id == activity.actor,
      # Are non-direct statuses with no to/cc possible?
      where:
        fragment(
          "not (? && ?)",
          [^public, sender.follower_address],
          activity.recipients
        )
    )
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

  defp restrict_since(query, %{"since_id" => since_id}) do
    from(activity in query, where: activity.id > ^since_id)
  end

  defp restrict_since(query, _), do: query

  defp restrict_tag(query, %{"tag" => tag}) do
    from(
      activity in query,
      where: fragment("? <@ (? #> '{\"object\",\"tag\"}')", ^tag, activity.data)
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

  defp restrict_limit(query, %{"limit" => limit}) do
    from(activity in query, limit: ^limit)
  end

  defp restrict_limit(query, _), do: query

  defp restrict_local(query, %{"local_only" => true}) do
    from(activity in query, where: activity.local == true)
  end

  defp restrict_local(query, _), do: query

  defp restrict_max(query, %{"max_id" => max_id}) do
    from(activity in query, where: activity.id < ^max_id)
  end

  defp restrict_max(query, _), do: query

  defp restrict_actor(query, %{"actor_id" => actor_id}) do
    from(activity in query, where: activity.actor == ^actor_id)
  end

  defp restrict_actor(query, _), do: query

  defp restrict_type(query, %{"type" => type}) when is_binary(type) do
    restrict_type(query, %{"type" => [type]})
  end

  defp restrict_type(query, %{"type" => type}) do
    from(activity in query, where: fragment("?->>'type' = ANY(?)", activity.data, ^type))
  end

  defp restrict_type(query, _), do: query

  defp restrict_favorited_by(query, %{"favorited_by" => ap_id}) do
    from(
      activity in query,
      where: fragment("? <@ (? #> '{\"object\",\"likes\"}')", ^ap_id, activity.data)
    )
  end

  defp restrict_favorited_by(query, _), do: query

  defp restrict_media(query, %{"only_media" => val}) when val == "true" or val == "1" do
    from(
      activity in query,
      where: fragment("not (? #> '{\"object\",\"attachment\"}' = ?)", activity.data, ^[])
    )
  end

  defp restrict_media(query, _), do: query

  # Only search through last 100_000 activities by default
  defp restrict_recent(query, %{"whole_db" => true}), do: query

  defp restrict_recent(query, _) do
    since = (Repo.aggregate(Activity, :max, :id) || 0) - 100_000

    from(activity in query, where: activity.id > ^since)
  end

  defp restrict_blocked(query, %{"blocking_user" => %User{info: info}}) do
    blocks = info["blocks"] || []

    from(
      activity in query,
      where: fragment("not (? = ANY(?))", activity.actor, ^blocks),
      where: fragment("not (?->'to' \\?| ?)", activity.data, ^blocks)
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
    |> restrict_since(opts)
    |> restrict_local(opts)
    |> restrict_limit(opts)
    |> restrict_max(opts)
    |> restrict_actor(opts)
    |> restrict_type(opts)
    |> restrict_favorited_by(opts)
    |> restrict_recent(opts)
    |> restrict_blocked(opts)
    |> restrict_media(opts)
    |> restrict_visibility(opts)
  end

  def fetch_activities(recipients, opts \\ %{}) do
    fetch_activities_query(recipients, opts)
    |> Repo.all()
    |> Enum.reverse()
  end

  def upload(file) do
    data = Upload.store(file)
    Repo.insert(%Object{data: data})
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
      nickname: "#{data["preferredUsername"]}@#{URI.parse(data["id"]).host}",
      name: data["name"],
      follower_address: data["followers"],
      bio: data["summary"]
    }

    {:ok, user_data}
  end

  def fetch_and_prepare_user_from_ap_id(ap_id) do
    with {:ok, %{status_code: 200, body: body}} <-
           @httpoison.get(ap_id, Accept: "application/activity+json"),
         {:ok, data} <- Jason.decode(body) do
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

  @quarantined_instances Keyword.get(@instance, :quarantined_instances, [])

  def should_federate?(inbox, public) do
    if public do
      true
    else
      inbox_info = URI.parse(inbox)
      inbox_info.host not in @quarantined_instances
    end
  end

  def publish(actor, activity) do
    followers =
      if actor.follower_address in activity.recipients do
        {:ok, followers} = User.get_followers(actor)
        followers |> Enum.filter(&(!&1.local))
      else
        []
      end

    public = is_public?(activity)

    remote_inboxes =
      (Pleroma.Web.Salmon.remote_users(activity) ++ followers)
      |> Enum.filter(fn user -> User.ap_enabled?(user) end)
      |> Enum.map(fn %{info: %{"source_data" => data}} ->
        (data["endpoints"] && data["endpoints"]["sharedInbox"]) || data["inbox"]
      end)
      |> Enum.uniq()
      |> Enum.filter(fn inbox -> should_federate?(inbox, public) end)

    {:ok, data} = Transmogrifier.prepare_outgoing(activity.data)
    json = Jason.encode!(data)

    Enum.each(remote_inboxes, fn inbox ->
      Federator.enqueue(:publish_single_ap, %{
        inbox: inbox,
        json: json,
        actor: actor,
        id: activity.data["id"]
      })
    end)
  end

  def publish_one(%{inbox: inbox, json: json, actor: actor, id: id}) do
    Logger.info("Federating #{id} to #{inbox}")
    host = URI.parse(inbox).host

    signature =
      Pleroma.Web.HTTPSignatures.sign(actor, %{host: host, "content-length": byte_size(json)})

    @httpoison.post(
      inbox,
      json,
      [{"Content-Type", "application/activity+json"}, {"signature", signature}],
      hackney: [pool: :default]
    )
  end

  # TODO:
  # This will create a Create activity, which we need internally at the moment.
  def fetch_object_from_id(id) do
    if object = Object.get_cached_by_ap_id(id) do
      {:ok, object}
    else
      Logger.info("Fetching #{id} via AP")

      with true <- String.starts_with?(id, "http"),
           {:ok, %{body: body, status_code: code}} when code in 200..299 <-
             @httpoison.get(
               id,
               [Accept: "application/activity+json"],
               follow_redirect: true,
               timeout: 10000,
               recv_timeout: 20000
             ),
           {:ok, data} <- Jason.decode(body),
           nil <- Object.get_by_ap_id(data["id"]),
           params <- %{
             "type" => "Create",
             "to" => data["to"],
             "cc" => data["cc"],
             "actor" => data["attributedTo"],
             "object" => data
           },
           {:ok, activity} <- Transmogrifier.handle_incoming(params) do
        {:ok, Object.get_by_ap_id(activity.data["object"]["id"])}
      else
        object = %Object{} ->
          {:ok, object}

        _e ->
          Logger.info("Couldn't get object via AP, trying out OStatus fetching...")

          case OStatus.fetch_activity_from_url(id) do
            {:ok, [activity | _]} -> {:ok, Object.get_by_ap_id(activity.data["object"]["id"])}
            e -> e
          end
      end
    end
  end

  def is_public?(activity) do
    "https://www.w3.org/ns/activitystreams#Public" in (activity.data["to"] ++
                                                         (activity.data["cc"] || []))
  end

  def visible_for_user?(activity, nil) do
    is_public?(activity)
  end

  def visible_for_user?(activity, user) do
    x = [user.ap_id | user.following]
    y = activity.data["to"] ++ (activity.data["cc"] || [])
    visible_for_user?(activity, nil) || Enum.any?(x, &(&1 in y))
  end
end
