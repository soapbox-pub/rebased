defmodule Pleroma.Web.TwitterAPI.Controller do
  use Pleroma.Web, :controller
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.Web.TwitterAPI.Representers.{UserRepresenter, ActivityRepresenter}

  def verify_credentials(%{assigns: %{user: user}} = conn, _params) do
    response = user |> UserRepresenter.to_json(%{for: user})

    conn
    |> json_reply(200, response)
  end

  def status_update(%{assigns: %{user: user}} = conn, status_data) do
    media_ids = extract_media_ids(status_data)
    {:ok, activity} = TwitterAPI.create_status(user, Map.put(status_data, "media_ids",  media_ids ))
    conn
    |> json_reply(200, ActivityRepresenter.to_json(activity, %{user: user}))
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

  def follow(%{assigns: %{user: user}} = conn, %{ "user_id" => followed_id }) do
    case TwitterAPI.follow(user, followed_id) do
      { :ok, _user, followed, _activity } ->
        response = followed |> UserRepresenter.to_json(%{for: user})
        conn |> json_reply(200, response)
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

  defp json_reply(conn, status, json) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json)
  end

  defp forbidden_json_reply(conn, error_message) do
    json = %{"error" => error_message, "request" => conn.request_path}
    |> Poison.encode!

    json_reply(conn, 403, json)
  end
end
