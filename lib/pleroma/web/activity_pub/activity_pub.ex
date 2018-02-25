defmodule Pleroma.Web.ActivityPub.ActivityPub do
  alias Pleroma.{Activity, Repo, Object, Upload, User, Notification}
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.WebFinger
  alias Pleroma.Web.Federator
  alias Pleroma.Web.OStatus
  import Ecto.Query
  import Pleroma.Web.ActivityPub.Utils
  require Logger

  @httpoison Application.get_env(:pleroma, :httpoison)

  def get_recipients(data) do
    (data["to"] || []) ++ (data["cc"] || [])
  end

  def insert(map, local \\ true) when is_map(map) do
    with nil <- Activity.get_by_ap_id(map["id"]),
         map <- lazy_put_activity_defaults(map),
         :ok <- insert_full_object(map) do
      {:ok, activity} = Repo.insert(%Activity{data: map, local: local, actor: map["actor"], recipients: get_recipients(map)})
      Notification.create_notifications(activity)
      stream_out(activity)
      {:ok, activity}
    else
      %Activity{} = activity -> {:ok, activity}
      error -> {:error, error}
    end
  end

  def stream_out(activity) do
    if activity.data["type"] in ["Create", "Announce"] do
      Pleroma.Web.Streamer.stream("user", activity)
      if Enum.member?(activity.data["to"], "https://www.w3.org/ns/activitystreams#Public") do
        Pleroma.Web.Streamer.stream("public", activity)
        if activity.local do
          Pleroma.Web.Streamer.stream("public:local", activity)
        end
      end
    end
  end

  def create(%{to: to, actor: actor, context: context, object: object} = params) do
    additional = params[:additional] || %{}
    local = !(params[:local] == false) # only accept false as false value
    published = params[:published]

    with create_data <- make_create_data(%{to: to, actor: actor, published: published, context: context, object: object}, additional),
         {:ok, activity} <- insert(create_data, local),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  def accept(%{to: to, actor: actor, object: object} = params) do
    local = !(params[:local] == false) # only accept false as false value

    with data <- %{"to" => to, "type" => "Accept", "actor" => actor, "object" => object},
         {:ok, activity} <- insert(data, local),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  def update(%{to: to, cc: cc, actor: actor, object: object} = params) do
    local = !(params[:local] == false) # only accept false as false value

    with data <- %{"to" => to, "cc" => cc, "type" => "Update", "actor" => actor, "object" => object},
         {:ok, activity} <- insert(data, local),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  # TODO: This is weird, maybe we shouldn't check here if we can make the activity.
  def like(%User{ap_id: ap_id} = user, %Object{data: %{"id" => _}} = object, activity_id \\ nil, local \\ true) do
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

  def unlike(%User{} = actor, %Object{} = object) do
    with %Activity{} = activity <- get_existing_like(actor.ap_id, object),
         {:ok, _activity} <- Repo.delete(activity),
         {:ok, object} <- remove_like_from_object(activity, object) do
      {:ok, object}
      else _e -> {:ok, object}
    end
  end

  def announce(%User{ap_id: _} = user, %Object{data: %{"id" => _}} = object, activity_id \\ nil, local \\ true) do
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

  def follow(follower, followed, activity_id \\ nil, local \\ true) do
    with data <- make_follow_data(follower, followed, activity_id),
         {:ok, activity} <- insert(data, local),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  def unfollow(follower, followed, local \\ true) do
    with %Activity{} = follow_activity <- fetch_latest_follow(follower, followed),
         unfollow_data <- make_unfollow_data(follower, followed, follow_activity),
         {:ok, activity} <- insert(unfollow_data, local),
         :ok, maybe_federate(activity) do
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
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  def fetch_activities_for_context(context, opts \\ %{}) do
    public = ["https://www.w3.org/ns/activitystreams#Public"]
    recipients = if opts["user"], do: [opts["user"].ap_id | opts["user"].following] ++ public, else: public

    query = from activity in Activity
    query = query
      |> restrict_blocked(opts)
      |> restrict_recipients(recipients, opts["user"])

   query = from activity in query,
      where: fragment("?->>'type' = ? and ?->>'context' = ?", activity.data, "Create", activity.data, ^context),
      order_by: [desc: :id]
    Repo.all(query)
  end

  def fetch_public_activities(opts \\ %{}) do
    public = %{to: ["https://www.w3.org/ns/activitystreams#Public"]}
    q = fetch_activities_query([], opts)
    q = from activity in q,
      where: fragment(~s(? @> ?), activity.data, ^public)
    q
    |> Repo.all
    |> Enum.reverse
  end

  defp restrict_since(query, %{"since_id" => since_id}) do
    from activity in query, where: activity.id > ^since_id
  end
  defp restrict_since(query, _), do: query

  defp restrict_tag(query, %{"tag" => tag}) do
    from activity in query,
      where: fragment("? <@ (? #> '{\"object\",\"tag\"}')", ^tag, activity.data)
  end
  defp restrict_tag(query, _), do: query

  defp restrict_recipients(query, [], user), do: query
  defp restrict_recipients(query, recipients, nil) do
    from activity in query,
     where: fragment("? && ?", ^recipients, activity.recipients)
  end
  defp restrict_recipients(query, recipients, user) do
    from activity in query,
      where: fragment("? && ?", ^recipients, activity.recipients),
      or_where: activity.actor == ^user.ap_id
  end

  defp restrict_local(query, %{"local_only" => true}) do
    from activity in query, where: activity.local == true
  end
  defp restrict_local(query, _), do: query

  defp restrict_max(query, %{"max_id" => max_id}) do
    from activity in query, where: activity.id < ^max_id
  end
  defp restrict_max(query, _), do: query

  defp restrict_actor(query, %{"actor_id" => actor_id}) do
    from activity in query,
      where: activity.actor == ^actor_id
  end
  defp restrict_actor(query, _), do: query

  defp restrict_type(query, %{"type" => type}) when is_binary(type) do
    restrict_type(query, %{"type" => [type]})
  end
  defp restrict_type(query, %{"type" => type}) do
    from activity in query,
      where: fragment("?->>'type' = ANY(?)", activity.data, ^type)
  end
  defp restrict_type(query, _), do: query

  defp restrict_favorited_by(query, %{"favorited_by" => ap_id}) do
    from activity in query,
      where: fragment("? <@ (? #> '{\"object\",\"likes\"}')", ^ap_id, activity.data)
  end
  defp restrict_favorited_by(query, _), do: query

  defp restrict_media(query, %{"only_media" => val}) when val == "true" or val == "1" do
    from activity in query,
      where: fragment("not (? #> '{\"object\",\"attachment\"}' = ?)", activity.data, ^[])
  end
  defp restrict_media(query, _), do: query

  # Only search through last 100_000 activities by default
  defp restrict_recent(query, %{"whole_db" => true}), do: query
  defp restrict_recent(query, _) do
    since = (Repo.aggregate(Activity, :max, :id) || 0) - 100_000

    from activity in query,
      where: activity.id > ^since
  end

  defp restrict_blocked(query, %{"blocking_user" => %User{info: info}}) do
    blocks = info["blocks"] || []
    from activity in query,
      where: fragment("not (? = ANY(?))", activity.actor, ^blocks)
  end
  defp restrict_blocked(query, _), do: query

  def fetch_activities_query(recipients, opts \\ %{}) do
    base_query = from activity in Activity,
      limit: 20,
      order_by: [fragment("? desc nulls last", activity.id)]

    base_query
    |> restrict_recipients(recipients, opts["user"])
    |> restrict_tag(opts)
    |> restrict_since(opts)
    |> restrict_local(opts)
    |> restrict_max(opts)
    |> restrict_actor(opts)
    |> restrict_type(opts)
    |> restrict_favorited_by(opts)
    |> restrict_recent(opts)
    |> restrict_blocked(opts)
    |> restrict_media(opts)
  end

  def fetch_activities(recipients, opts \\ %{}) do
    fetch_activities_query(recipients, opts)
    |> Repo.all
    |> Enum.reverse
  end

  def upload(file) do
    data = Upload.store(file)
    Repo.insert(%Object{data: data})
  end

  def user_data_from_user_object(data) do
    avatar = data["icon"]["url"] && %{
      "type" => "Image",
      "url" => [%{"href" => data["icon"]["url"]}]
    }

    banner = data["image"]["url"] && %{
      "type" => "Image",
      "url" => [%{"href" => data["image"]["url"]}]
    }

    user_data = %{
      ap_id: data["id"],
      info: %{
        "ap_enabled" => true,
        "source_data" => data,
        "banner" => banner
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
    with {:ok, %{status_code: 200, body: body}} <- @httpoison.get(ap_id, ["Accept": "application/activity+json"]),
    {:ok, data} <- Poison.decode(body) do
      user_data_from_user_object(data)
    else
      e -> Logger.error("Could not user at fetch #{ap_id}, #{inspect(e)}")
    end
  end

  def make_user_from_ap_id(ap_id) do
    if user = User.get_by_ap_id(ap_id) do
      Transmogrifier.upgrade_user_from_ap_id(ap_id)
    else
      with {:ok, data} <- fetch_and_prepare_user_from_ap_id(ap_id) do
        User.insert_or_update_user(data)
      else
        e -> e
      end
    end
  end

  def make_user_from_nickname(nickname) do
    with {:ok, %{"ap_id" => ap_id}} when not is_nil(ap_id) <- WebFinger.finger(nickname) do
      make_user_from_ap_id(ap_id)
    end
  end

  def publish(actor, activity) do
    followers = if actor.follower_address in activity.recipients do
      {:ok, followers} = User.get_followers(actor)
      followers |> Enum.filter(&(!&1.local))
    else
      []
    end

    remote_inboxes = (Pleroma.Web.Salmon.remote_users(activity) ++ followers)
    |> Enum.filter(fn (user) -> User.ap_enabled?(user) end)
    |> Enum.map(fn (%{info: %{"source_data" => data}}) ->
      (data["endpoints"] && data["endpoints"]["sharedInbox"]) || data["inbox"]
    end)
    |> Enum.uniq

    {:ok, data} = Transmogrifier.prepare_outgoing(activity.data)
    json = Poison.encode!(data)
    Enum.each remote_inboxes, fn(inbox) ->
      Federator.enqueue(:publish_single_ap, %{inbox: inbox, json: json, actor: actor, id: activity.data["id"]})
    end
  end

  def publish_one(%{inbox: inbox, json: json, actor: actor, id: id}) do
    Logger.info("Federating #{id} to #{inbox}")
    host = URI.parse(inbox).host
    signature = Pleroma.Web.HTTPSignatures.sign(actor, %{host: host, "content-length": byte_size(json)})
    @httpoison.post(inbox, json, [{"Content-Type", "application/activity+json"}, {"signature", signature}])
  end

  # TODO:
  # This will create a Create activity, which we need internally at the moment.
  def fetch_object_from_id(id) do
    if object = Object.get_cached_by_ap_id(id) do
      {:ok, object}
    else
      Logger.info("Fetching #{id} via AP")
      with {:ok, %{body: body, status_code: code}} when code in 200..299 <- @httpoison.get(id, [Accept: "application/activity+json"], follow_redirect: true, timeout: 10000, recv_timeout: 20000),
           {:ok, data} <- Poison.decode(body),
           nil <- Object.get_by_ap_id(data["id"]),
           params <- %{"type" => "Create", "to" => data["to"], "cc" => data["cc"], "actor" => data["attributedTo"], "object" => data},
           {:ok, activity} <- Transmogrifier.handle_incoming(params) do
        {:ok, Object.get_by_ap_id(activity.data["object"]["id"])}
      else
        object = %Object{} -> {:ok, object}
        e ->
          Logger.info("Couldn't get object via AP, trying out OStatus fetching...")
          case OStatus.fetch_activity_from_url(id) do
            {:ok, [activity | _]} -> {:ok, Object.get_by_ap_id(activity.data["object"]["id"])}
            e -> e
          end
      end
    end
  end

  def is_public?(activity) do
    "https://www.w3.org/ns/activitystreams#Public" in (activity.data["to"] ++ (activity.data["cc"] || []))
  end

  def visible_for_user?(activity, nil) do
    is_public?(activity)
  end
  def visible_for_user?(activity, user) do
    x = [user.ap_id | user.following]
    y = (activity.data["to"] ++ (activity.data["cc"] || []))
    visible_for_user?(activity, nil) || Enum.any?(x, &(&1 in y))
  end
end
