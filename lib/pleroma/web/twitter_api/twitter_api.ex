defmodule Pleroma.Web.TwitterAPI.TwitterAPI do
  alias Pleroma.{User, Activity, Repo, Object}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.TwitterAPI.UserView
  alias Pleroma.Web.{OStatus, CommonAPI}
  import Ecto.Query

  @httpoison Application.get_env(:pleroma, :httpoison)

  def create_status(%User{} = user, %{"status" => _} = data) do
    CommonAPI.post(user, data)
  end

  def delete(%User{} = user, id) do
    # TwitterAPI does not have an "unretweet" endpoint; instead this is done
    # via the "destroy" endpoint.  Therefore, we need to handle
    # when the status to "delete" is actually an Announce (repeat) object.
    with %Activity{data: %{"type" => type}} <- Repo.get(Activity, id) do
      case type do
        "Announce" -> unrepeat(user, id)
        _ -> CommonAPI.delete(id, user)
      end
    end
  end

  def follow(%User{} = follower, params) do
    with {:ok, %User{} = followed} <- get_user(params),
         {:ok, follower} <- User.follow(follower, followed),
         {:ok, activity} <- ActivityPub.follow(follower, followed) do
      {:ok, follower, followed, activity}
    else
      err -> err
    end
  end

  def unfollow(%User{} = follower, params) do
    with {:ok, %User{} = unfollowed} <- get_user(params),
         {:ok, follower, follow_activity} <- User.unfollow(follower, unfollowed),
         {:ok, _activity} <- ActivityPub.unfollow(follower, unfollowed) do
      {:ok, follower, unfollowed}
    else
      err -> err
    end
  end

  def block(%User{} = blocker, params) do
    with {:ok, %User{} = blocked} <- get_user(params),
         {:ok, blocker} <- User.block(blocker, blocked) do
      {:ok, blocker, blocked}
    else
      err -> err
    end
  end

  def unblock(%User{} = blocker, params) do
    with {:ok, %User{} = blocked} <- get_user(params),
         {:ok, blocker} <- User.unblock(blocker, blocked) do
      {:ok, blocker, blocked}
    else
      err -> err
    end
  end

  def repeat(%User{} = user, ap_id_or_id) do
    with {:ok, _announce, %{data: %{"id" => id}}} = CommonAPI.repeat(ap_id_or_id, user),
         %Activity{} = activity <- Activity.get_create_activity_by_object_ap_id(id) do
      {:ok, activity}
    end
  end

  defp unrepeat(%User{} = user, ap_id_or_id) do
    with {:ok, _unannounce, activity, _object} <- CommonAPI.unrepeat(ap_id_or_id, user) do
      {:ok, activity}
    end
  end

  def fav(%User{} = user, ap_id_or_id) do
    with {:ok, _fav, %{data: %{"id" => id}}} = CommonAPI.favorite(ap_id_or_id, user),
         %Activity{} = activity <- Activity.get_create_activity_by_object_ap_id(id) do
      {:ok, activity}
    end
  end

  def unfav(%User{} = user, ap_id_or_id) do
    with {:ok, _unfav, _fav, %{data: %{"id" => id}}} = CommonAPI.unfavorite(ap_id_or_id, user),
         %Activity{} = activity <- Activity.get_create_activity_by_object_ap_id(id) do
      {:ok, activity}
    end
  end

  def upload(%Plug.Upload{} = file, format \\ "xml") do
    {:ok, object} = ActivityPub.upload(file)

    url = List.first(object.data["url"])
    href = url["href"]
    type = url["mediaType"]

    case format do
      "xml" ->
        # Fake this as good as possible...
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <rsp stat="ok" xmlns:atom="http://www.w3.org/2005/Atom">
        <mediaid>#{object.id}</mediaid>
        <media_id>#{object.id}</media_id>
        <media_id_string>#{object.id}</media_id_string>
        <media_url>#{href}</media_url>
        <mediaurl>#{href}</mediaurl>
        <atom:link rel="enclosure" href="#{href}" type="#{type}"></atom:link>
        </rsp>
        """

      "json" ->
        %{
          media_id: object.id,
          media_id_string: "#{object.id}}",
          media_url: href,
          size: 0
        }
        |> Jason.encode!()
    end
  end

  def register_user(params) do
    params = %{
      nickname: params["nickname"],
      name: params["fullname"],
      bio: params["bio"],
      email: params["email"],
      password: params["password"],
      password_confirmation: params["confirm"]
    }

    changeset = User.register_changeset(%User{}, params)

    with {:ok, user} <- Repo.insert(changeset) do
      {:ok, user}
    else
      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
          |> Jason.encode!()

        {:error, %{error: errors}}
    end
  end

  def get_by_id_or_nickname(id_or_nickname) do
    if !is_integer(id_or_nickname) && :error == Integer.parse(id_or_nickname) do
      Repo.get_by(User, nickname: id_or_nickname)
    else
      Repo.get(User, id_or_nickname)
    end
  end

  def get_user(user \\ nil, params) do
    case params do
      %{"user_id" => user_id} ->
        case target = get_by_id_or_nickname(user_id) do
          nil ->
            {:error, "No user with such user_id"}

          _ ->
            {:ok, target}
        end

      %{"screen_name" => nickname} ->
        case target = Repo.get_by(User, nickname: nickname) do
          nil ->
            {:error, "No user with such screen_name"}

          _ ->
            {:ok, target}
        end

      _ ->
        if user do
          {:ok, user}
        else
          {:error, "You need to specify screen_name or user_id"}
        end
    end
  end

  defp parse_int(string, default)

  defp parse_int(string, default) when is_binary(string) do
    with {n, _} <- Integer.parse(string) do
      n
    else
      _e -> default
    end
  end

  defp parse_int(_, default), do: default

  def search(_user, %{"q" => query} = params) do
    limit = parse_int(params["rpp"], 20)
    page = parse_int(params["page"], 1)
    offset = (page - 1) * limit

    q =
      from(
        a in Activity,
        where: fragment("?->>'type' = 'Create'", a.data),
        where: "https://www.w3.org/ns/activitystreams#Public" in a.recipients,
        where:
          fragment(
            "to_tsvector('english', ?->'object'->>'content') @@ plainto_tsquery('english', ?)",
            a.data,
            ^query
          ),
        limit: ^limit,
        offset: ^offset,
        # this one isn't indexed so psql won't take the wrong index.
        order_by: [desc: :inserted_at]
      )

    _activities = Repo.all(q)
  end

  defp make_date do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  # DEPRECATED mostly, context objects are now created at insertion time.
  def context_to_conversation_id(context) do
    with %Object{id: id} <- Object.get_cached_by_ap_id(context) do
      id
    else
      _e ->
        changeset = Object.context_mapping(context)

        case Repo.insert(changeset) do
          {:ok, %{id: id}} ->
            id

          # This should be solved by an upsert, but it seems ecto
          # has problems accessing the constraint inside the jsonb.
          {:error, _} ->
            Object.get_cached_by_ap_id(context).id
        end
    end
  end

  def conversation_id_to_context(id) do
    with %Object{data: %{"id" => context}} <- Repo.get(Object, id) do
      context
    else
      _e ->
        {:error, "No such conversation"}
    end
  end

  def get_external_profile(for_user, uri) do
    with %User{} = user <- User.get_or_fetch(uri) do
      spawn(fn ->
        with url <- user.info["topic"],
             {:ok, %{body: body}} <-
               @httpoison.get(url, [], follow_redirect: true, timeout: 10000, recv_timeout: 20000) do
          OStatus.handle_incoming(body)
        end
      end)

      {:ok, UserView.render("show.json", %{user: user, for: for_user})}
    else
      _e ->
        {:error, "Couldn't find user"}
    end
  end
end
