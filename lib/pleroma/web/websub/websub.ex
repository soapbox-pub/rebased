defmodule Pleroma.Web.Websub do
  alias Pleroma.Repo
  alias Pleroma.Websub
  alias Pleroma.Web.Websub.WebsubServerSubscription
  alias Pleroma.Web.OStatus.FeedRepresenter

  import Ecto.Query

  def verify(subscription, getter \\ &HTTPoison.get/3 ) do
    challenge = Base.encode16(:crypto.strong_rand_bytes(8))
    lease_seconds = NaiveDateTime.diff(subscription.valid_until, subscription.inserted_at) |> to_string

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
end
