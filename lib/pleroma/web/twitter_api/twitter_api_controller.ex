defmodule Pleroma.Web.TwitterAPI.Controller do
  use Pleroma.Web, :controller
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.Web.TwitterAPI.Representers.{UserRepresenter, ActivityRepresenter}

  def verify_credentials(%{assigns: %{user: user}} = conn, _params) do
    response = user |> UserRepresenter.to_json

    conn
    |> json_reply(200, response)
  end

  def status_update(%{assigns: %{user: user}} = conn, status_data) do
    {:ok, activity} = TwitterAPI.create_status(user, status_data)
    conn
    |> json_reply(200, ActivityRepresenter.to_json(activity, %{user: user}))
  end

  def public_timeline(conn, params) do
    statuses = TwitterAPI.fetch_public_statuses(params)
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
    { :ok, _user, follower } = TwitterAPI.follow(user, followed_id)

    response = follower |> UserRepresenter.to_json

    conn
    |> json_reply(200, response)
  end

  defp json_reply(conn, status, json) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json)
  end
end
