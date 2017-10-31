defmodule Pleroma.Web.ActivityPub.ActivityPub do
  alias Pleroma.{Activity, Repo, Object, Upload, User, Web, Notification}
  alias Ecto.{Changeset, UUID}
  import Ecto.Query
  import Pleroma.Web.ActivityPub.Utils
  require Logger

  def insert(map, local \\ true) when is_map(map) do
    with nil <- Activity.get_by_ap_id(map["id"]),
         map <- lazy_put_activity_defaults(map),
         :ok <- insert_full_object(map) do
      {:ok, activity} = Repo.insert(%Activity{data: map, local: local})
      Notification.create_notifications(activity)
      {:ok, activity}
    else
      %Activity{} = activity -> {:ok, activity}
      error -> {:error, error}
    end
  end

  def create(to, actor, context, object, additional \\ %{}, published \\ nil, local \\ true) do
    with create_data <- make_create_data(%{to: to, actor: actor, published: published, context: context, object: object}, additional),
         {:ok, activity} <- insert(create_data, local),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  # TODO: This is weird, maybe we shouldn't check here if we can make the activity.
  def like(%User{ap_id: ap_id} = user, %Object{data: %{"id" => id}} = object, activity_id \\ nil, local \\ true) do
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

  def announce(%User{ap_id: ap_id} = user, %Object{data: %{"id" => id}} = object, activity_id \\ nil, local \\ true) do
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

  def fetch_activities_for_context(context) do
    query = from activity in Activity,
      where: fragment("?->>'type' = ? and ?->>'context' = ?", activity.data, "Create", activity.data, ^context),
      order_by: [desc: :id]
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
      where: fragment("?->>'actor' = ?", activity.data, ^actor_id)
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

  # Only search through last 100_000 activities by default
  defp restrict_recent(query, _) do
    since = Repo.aggregate(Activity, :max, :id) - 100_000

    from activity in query,
      where: activity.id > ^since
  end

  def fetch_activities(recipients, opts \\ %{}) do
    base_query = from activity in Activity,
      limit: 20,
      order_by: [desc: :id]

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
    |> Repo.all
    |> Enum.reverse
  end

  def upload(file) do
    data = Upload.store(file)
    Repo.insert(%Object{data: data})
  end
end
