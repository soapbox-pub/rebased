defmodule Pleroma.Web.ActivityPub.ActivityPub do
  alias Pleroma.{Activity, Repo, Object, Upload, User, Web}
  alias Ecto.{Changeset, UUID}
  import Ecto.Query
  import Pleroma.Web.ActivityPub.Utils
  require Logger

  def insert(map, local \\ true) when is_map(map) do
    with nil <- Activity.get_by_ap_id(map["id"]),
         map <- lazy_put_activity_defaults(map),
         :ok <- insert_full_object(map) do
      Repo.insert(%Activity{data: map, local: local})
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

  def fetch_activities_for_context(context) do
    query = from activity in Activity,
      where: fragment("? @> ?", activity.data, ^%{ type: "Create", context: context }),
      order_by: [desc: :inserted_at]
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

  def fetch_activities(recipients, opts \\ %{}) do
    base_query = from activity in Activity,
      limit: 20,
      order_by: [desc: :id]

    base_query
    |> restrict_recipients(recipients)
    |> restrict_since(opts)
    |> restrict_local(opts)
    |> restrict_max(opts)
    |> restrict_actor(opts)
    |> Repo.all
    |> Enum.reverse
  end

  def upload(file) do
    data = Upload.store(file)
    Repo.insert(%Object{data: data})
  end
end
