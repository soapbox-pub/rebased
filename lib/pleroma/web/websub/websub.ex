defmodule Pleroma.Web.Websub do
  alias Pleroma.Repo
  alias Pleroma.Websub
  alias Pleroma.Web.Websub.WebsubServerSubscription
  alias Pleroma.Web.OStatus.FeedRepresenter
  alias Pleroma.Web.OStatus

  import Ecto.Query

  @websub_verifier Application.get_env(:pleroma, :websub_verifier)

  def verify(subscription, getter \\ &HTTPoison.get/3 ) do
    challenge = Base.encode16(:crypto.strong_rand_bytes(8))
    lease_seconds = NaiveDateTime.diff(subscription.valid_until, subscription.updated_at) |> to_string

    params = %{
      "hub.challenge": challenge,
      "hub.lease_seconds": lease_seconds,
      "hub.topic": subscription.topic,
      "hub.mode": "subscribe"
    }

    url = hd(String.split(subscription.callback, "?"))
    query = URI.parse(subscription.callback).query || ""
    params = Map.merge(params, URI.decode_query(query))
    with {:ok, response} <- getter.(url, [], [params: params]),
         ^challenge <- response.body
    do
      changeset = Ecto.Changeset.change(subscription, %{state: "active"})
      Repo.update(changeset)
    else _e ->
      changeset = Ecto.Changeset.change(subscription, %{state: "rejected"})
      {:ok, subscription } = Repo.update(changeset)
      {:error, subscription}
    end
  end

  def publish(topic, user, activity) do
    query = from sub in WebsubServerSubscription,
    where: sub.topic == ^topic and sub.state == "active"
    subscriptions = Repo.all(query)
    Enum.each(subscriptions, fn(sub) ->
      response = FeedRepresenter.to_simple_form(user, [activity], [user])
      |> :xmerl.export_simple(:xmerl_xml)

      signature = :crypto.hmac(:sha, sub.secret, response) |> Base.encode16

      HTTPoison.post(sub.callback, response, [
            {"Content-Type", "application/atom+xml"},
            {"X-Hub-Signature", "sha1=#{signature}"}
          ])
    end)
  end

  def incoming_subscription_request(user, params) do
    with {:ok, topic} <- valid_topic(params, user),
         {:ok, lease_time} <- lease_time(params),
         secret <- params["hub.secret"],
         callback <- params["hub.callback"]
    do
      subscription = get_subscription(topic, callback)
      data = %{
        state: subscription.state || "requested",
        topic: topic,
        secret: secret,
        callback: callback
      }

      change = Ecto.Changeset.change(subscription, data)
      websub = Repo.insert_or_update!(change)

      change = Ecto.Changeset.change(websub, %{valid_until: NaiveDateTime.add(websub.updated_at, lease_time)})
      websub = Repo.update!(change)

      # Just spawn that for now, maybe pool later.
      spawn(fn -> @websub_verifier.verify(websub) end)

      {:ok, websub}
    else {:error, reason} ->
      {:error, reason}
    end
  end

  defp get_subscription(topic, callback) do
    Repo.get_by(WebsubServerSubscription, topic: topic, callback: callback) || %WebsubServerSubscription{}
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
