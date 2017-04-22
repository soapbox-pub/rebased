defmodule Pleroma.Web.Websub.WebsubController do
  use Pleroma.Web, :controller
  alias Pleroma.Web.Websub.WebsubServerSubscription
  alias Pleroma.{Repo, User}
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.Websub
  def websub_subscription_request(conn, %{"nickname" => nickname} = params) do
    user = User.get_cached_by_nickname(nickname)

    with {:ok, topic} <- valid_topic(params, user),
         {:ok, lease_time} <- lease_time(params),
         secret <- params["hub.secret"]
    do
      data = %{
        state: "requested",
        topic: topic,
        secret: secret,
        callback: params["hub.callback"]
      }

      change = Ecto.Changeset.change(%WebsubServerSubscription{}, data)
      websub = Repo.insert!(change)

      change = Ecto.Changeset.change(websub, %{valid_until: NaiveDateTime.add(websub.inserted_at, lease_time)})
      websub = Repo.update!(change)

      # Just spawn that for now, maybe pool later.
      spawn(fn -> Websub.verify(websub) end)

      conn
      |> send_resp(202, "Accepted")
    else {:error, reason} ->
      conn
      |> send_resp(500, reason)
    end
  end

  defp lease_time(%{"hub.lease_seconds" => lease_seconds}) do
    {:ok, String.to_integer(lease_seconds)}
  end

  defp lease_time(_) do
    {:ok, 60 * 60 * 24 * 3} # three days
  end

  defp valid_topic(%{"hub.topic" => topic}, user) do
    if topic == OStatus.feed_path(user) do
      {:ok, topic}
    else
      {:error, "Wrong topic requested, expected #{OStatus.feed_path(user)}, got #{topic}"}
    end
  end
end
