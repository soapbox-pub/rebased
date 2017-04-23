defmodule Pleroma.Web.TwitterAPI.Controller do
  use Pleroma.Web, :controller
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.Web.TwitterAPI.Representers.{UserRepresenter, ActivityRepresenter}
  alias Pleroma.{Repo, Activity}
  alias Pleroma.Web.ActivityPub.ActivityPub

  def verify_credentials(%{assigns: %{user: user}} = conn, _params) do
    response = user |> UserRepresenter.to_json(%{for: user})

    conn
    |> json_reply(200, response)
  end

  def status_update(conn, %{"status" => ""} = _status_data) do
    empty_status_reply(conn)
  end

  def status_update(%{assigns: %{user: user}} = conn, %{"status" => _status_text} = status_data) do
    media_ids = extract_media_ids(status_data)
    {:ok, activity} = TwitterAPI.create_status(user, Map.put(status_data, "media_ids",  media_ids ))
    conn
    |> json_reply(200, ActivityRepresenter.to_json(activity, %{user: user}))
  end

  def status_update(conn, _status_data) do
    empty_status_reply(conn)
  end

  defp empty_status_reply(conn) do
    bad_request_reply(conn, "Client must provide a 'status' parameter with a value.")
  end

  defp extract_media_ids(status_data) do
    with media_ids when not is_nil(media_ids) <- status_data["media_ids"],
         split_ids <- String.split(media_ids, ","),
         clean_ids <- Enum.reject(split_ids, fn (id) -> String.length(id) == 0 end)
      do
        clean_ids
      else _e -> []
    end
  end

  def public_timeline(%{assigns: %{user: user}} = conn, params) do
    statuses = TwitterAPI.fetch_public_statuses(user, params)
    {:ok, json} = Poison.encode(statuses)

    conn
    |> json_reply(200, json)
  end

  def friends_timeline(%{assigns: %{user: user}} = conn, params) do
    statuses = TwitterAPI.fetch_friend_statuses(user, params)
    {:ok, json} = Poison.encode(statuses)

    conn
    |> json_reply(200, json)
  end

  def user_timeline(%{assigns: %{user: user}} = conn, params) do
    case TwitterAPI.get_user(user, params) do
      {:ok, target_user} ->
        params = Map.merge(params, %{"actor_id" => target_user.ap_id})
        statuses  = TwitterAPI.fetch_user_statuses(user, params)
        conn
        |> json_reply(200, statuses |> Poison.encode!)
      {:error, msg} ->
        bad_request_reply(conn, msg)
    end
  end

  def mentions_timeline(%{assigns: %{user: user}} = conn, params) do
    statuses = TwitterAPI.fetch_mentions(user, params)
    {:ok, json} = Poison.encode(statuses)

    conn
    |> json_reply(200, json)
  end

  def follow(%{assigns: %{user: user}} = conn, %{ "user_id" => followed_id }) do
    case TwitterAPI.follow(user, followed_id) do
      { :ok, user, followed, _activity } ->
        response = followed |> UserRepresenter.to_json(%{for: user})
        conn
        |> json_reply(200, response)
      { :error, msg } -> forbidden_json_reply(conn, msg)
    end
  end

  def unfollow(%{assigns: %{user: user}} = conn, %{ "user_id" => followed_id }) do
    case TwitterAPI.unfollow(user, followed_id) do
      { :ok, user, followed } ->
        response = followed |> UserRepresenter.to_json(%{for: user})

        conn
        |> json_reply(200, response)
      { :error, msg } -> forbidden_json_reply(conn, msg)
    end
  end

  def fetch_status(%{assigns: %{user: user}} = conn, %{ "id" => id }) do
    response = TwitterAPI.fetch_status(user, id) |> Poison.encode!

    conn
    |> json_reply(200, response)
  end

  def fetch_conversation(%{assigns: %{user: user}} = conn, %{ "id" => id }) do
    id = String.to_integer(id)
    response = TwitterAPI.fetch_conversation(user, id) |> Poison.encode!

    conn
    |> json_reply(200, response)
  end

  def upload(conn, %{"media" => media}) do
    response = TwitterAPI.upload(media)
    conn
    |> put_resp_content_type("application/atom+xml")
    |> send_resp(200, response)
  end

  def help_test(conn, _params) do
    conn |> json_reply(200, Poison.encode!("ok"))
  end

  def upload_json(conn, %{"media" => media}) do
    response = TwitterAPI.upload(media, "json")
    conn
    |> json_reply(200, response)
  end

  def config(conn, _params) do
    response = %{
      site: %{
        name: Pleroma.Web.base_url,
        server: Pleroma.Web.base_url,
        textlimit: -1
      }
    }
    |> Poison.encode!

    conn
    |> json_reply(200, response)
  end

  def favorite(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    activity = Repo.get(Activity, id)
    {:ok, status} = TwitterAPI.favorite(user, activity)
    response = Poison.encode!(status)

    conn
    |> json_reply(200, response)
  end

  def unfavorite(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    activity = Repo.get(Activity, id)
    {:ok, status} = TwitterAPI.unfavorite(user, activity)
    response = Poison.encode!(status)

    conn
    |> json_reply(200, response)
  end

  def retweet(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    activity = Repo.get(Activity, id)
    {:ok, status} = TwitterAPI.retweet(user, activity)
    response = Poison.encode!(status)

    conn
    |> json_reply(200, response)
  end

  def register(conn, params) do
    with {:ok, user} <- TwitterAPI.register_user(params) do
      conn
      |> json_reply(200, Poison.encode!(user))
    else
      {:error, errors} ->
      conn
      |> json_reply(400, Poison.encode!(errors))
    end
  end

  def update_avatar(%{assigns: %{user: user}} = conn, params) do
    {:ok, object} = ActivityPub.upload(params)
    change = Ecto.Changeset.change(user, %{avatar: object.data})
    {:ok, user} = Repo.update(change)

    response = UserRepresenter.to_map(user, %{for: user})
    |> Poison.encode!

    conn
    |> json_reply(200, response)
  end

  defp bad_request_reply(conn, error_message) do
    json = error_json(conn, error_message)
    json_reply(conn, 400, json)
  end

  defp json_reply(conn, status, json) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json)
  end

  defp forbidden_json_reply(conn, error_message) do
    json = error_json(conn, error_message)
    json_reply(conn, 403, json)
  end

  defp error_json(conn, error_message) do
    %{"error" => error_message, "request" => conn.request_path} |> Poison.encode!
  end
end
