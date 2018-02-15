defmodule Pleroma.Web.ActivityPub.ActivityPub do
  alias Pleroma.{Activity, Repo, Object, Upload, User, Notification}
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
    with announce_data <- make_announce_data(user, object, activity_id),
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
    query = from activity in Activity,
      where: fragment("?->>'type' = ? and ?->>'context' = ?", activity.data, "Create", activity.data, ^context),
      order_by: [desc: :id]
    query = restrict_blocked(query, opts)
    Repo.all(query)
  end

  def fetch_public_activities(opts \\ %{}) do
    public = ["https://www.w3.org/ns/activitystreams#Public"]
    fetch_activities(public, opts)
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

  defp restrict_recipients(query, recipients) do
    Enum.reduce(recipients, query, fn (recipient, q) ->
      map = %{ to: [recipient] }
      from activity in q,
      or_where: fragment(~s(? @> ?), activity.data, ^map)
    end)
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

  def fetch_activities(recipients, opts \\ %{}) do
    base_query = from activity in Activity,
      limit: 20,
      order_by: [fragment("? desc nulls last", activity.id)]

    base_query
    |> restrict_recipients(recipients)
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
    |> Repo.all
    |> Enum.reverse
  end

  def upload(file) do
    data = Upload.store(file)
    Repo.insert(%Object{data: data})
  end

  def make_user_from_ap_id(ap_id) do
    with {:ok, %{status_code: 200, body: body}} <- @httpoison.get(ap_id, ["Accept": "application/activity+json"]),
    {:ok, data} <- Poison.decode(body)
      do
      user_data = %{
        ap_id: data["id"],
        info: %{
          "ap_enabled" => true,
          "source_data" => data
        },
        nickname: "#{data["preferredUsername"]}@#{URI.parse(ap_id).host}",
        name: data["name"]
      }

      User.insert_or_update_user(user_data)
    end
  end

  # TODO: Extract to own module, align as close to Mastodon format as possible.
  def sanitize_outgoing_activity_data(data) do
    data
    |> Map.put("@context", "https://www.w3.org/ns/activitystreams")
  end

  def publish(actor, activity) do
    remote_users = Pleroma.Web.Salmon.remote_users(activity)
    data = sanitize_outgoing_activity_data(activity.data)
    Enum.each remote_users, fn(user) ->
      if user.info["ap_enabled"] do
        inbox = user.info["source_data"]["inbox"]
        Logger.info("Federating #{activity.data["id"]} to #{inbox}")
        host = URI.parse(inbox).host
        signature = Pleroma.Web.HTTPSignatures.sign(actor, %{host: host})
        @httpoison.post(inbox, Poison.encode!(data), [{"Content-Type", "application/activity+json"}, {"signature", signature}])
      end
    end
  end
end
