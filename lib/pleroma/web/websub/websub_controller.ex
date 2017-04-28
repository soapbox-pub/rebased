defmodule Pleroma.Web.Websub.WebsubController do
  use Pleroma.Web, :controller
  alias Pleroma.{Repo, User}
  alias Pleroma.Web.Websub
  alias Pleroma.Web.Websub.WebsubClientSubscription
  require Logger

  @ostatus Application.get_env(:pleroma, :ostatus)

  def websub_subscription_request(conn, %{"nickname" => nickname} = params) do
    user = User.get_cached_by_nickname(nickname)

    with {:ok, _websub} <- Websub.incoming_subscription_request(user, params)
    do
      conn
      |> send_resp(202, "Accepted")
    else {:error, reason} ->
      conn
      |> send_resp(500, reason)
    end
  end

  def websub_subscription_confirmation(conn, %{"id" => id, "hub.mode" => "subscribe", "hub.challenge" => challenge, "hub.topic" => topic}) do
    with %WebsubClientSubscription{} = websub <- Repo.get_by(WebsubClientSubscription, id: id, topic: topic) do
      change = Ecto.Changeset.change(websub, %{state: "accepted"})
      {:ok, _websub} = Repo.update(change)
      conn
      |> send_resp(200, challenge)
    else _e ->
      conn
      |> send_resp(500, "Error")
    end
  end

  def websub_incoming(conn, %{"id" => id}) do
    with "sha1=" <> signature <- hd(get_req_header(conn, "x-hub-signature")),
         %WebsubClientSubscription{} = websub <- Repo.get(WebsubClientSubscription, id),
         {:ok, body, _conn} = read_body(conn),
         ^signature <- Websub.sign(websub.secret, body) do
      @ostatus.handle_incoming(body)
      conn
      |> send_resp(200, "OK")
    else _e ->
      Logger.debug("Can't handle incoming subscription post")
      conn
      |> send_resp(500, "Error")
    end
  end
end
