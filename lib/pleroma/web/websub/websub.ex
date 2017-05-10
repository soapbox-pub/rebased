defmodule Pleroma.Web.Websub do
  alias Ecto.Changeset
  alias Pleroma.Repo
  alias Pleroma.Web.Websub.{WebsubServerSubscription, WebsubClientSubscription}
  alias Pleroma.Web.OStatus.FeedRepresenter
  alias Pleroma.Web.{XML, Endpoint, OStatus}
  alias Pleroma.Web.Router.Helpers
  require Logger

  import Ecto.Query

  @httpoison Application.get_env(:pleroma, :httpoison)

  def verify(subscription, getter \\ &@httpoison.get/3) do
    challenge = Base.encode16(:crypto.strong_rand_bytes(8))
    lease_seconds = NaiveDateTime.diff(subscription.valid_until, subscription.updated_at)
    lease_seconds = lease_seconds |> to_string

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
      changeset = Changeset.change(subscription, %{state: "active"})
      Repo.update(changeset)
    else _e ->
      changeset = Changeset.change(subscription, %{state: "rejected"})
      {:ok, subscription} = Repo.update(changeset)
      {:error, subscription}
    end
  end

  def publish(topic, user, activity) do
    query = from sub in WebsubServerSubscription,
    where: sub.topic == ^topic and sub.state == "active"
    subscriptions = Repo.all(query)
    Enum.each(subscriptions, fn(sub) ->
      response = user
      |> FeedRepresenter.to_simple_form([activity], [user])
      |> :xmerl.export_simple(:xmerl_xml)
      |> to_string

      signature = sign(sub.secret || "", response)
      Logger.debug(fn -> "Pushing to #{sub.callback}" end)

      Task.start(fn ->
        @httpoison.post(sub.callback, response, [
              {"Content-Type", "application/atom+xml"},
              {"X-Hub-Signature", "sha1=#{signature}"}
            ])
      end)
    end)
  end

  def sign(secret, doc) do
    :crypto.hmac(:sha, secret, to_string(doc)) |> Base.encode16 |> String.downcase
  end

  def incoming_subscription_request(user, %{"hub.mode" => "subscribe"} = params) do
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

      change = Changeset.change(subscription, data)
      websub = Repo.insert_or_update!(change)

      change = Changeset.change(websub, %{valid_until:
                                          NaiveDateTime.add(websub.updated_at, lease_time)})
      websub = Repo.update!(change)

      Pleroma.Web.Federator.enqueue(:verify_websub, websub)

      {:ok, websub}
    else {:error, reason} ->
      Logger.debug("Couldn't create subscription.")
      Logger.debug(inspect(reason))

      {:error, reason}
    end
  end

  defp get_subscription(topic, callback) do
    Repo.get_by(WebsubServerSubscription, topic: topic, callback: callback) ||
      %WebsubServerSubscription{}
  end

  # Temp hack for mastodon.
  defp lease_time(%{"hub.lease_seconds" => ""}) do
    {:ok, 60 * 60 * 24 * 3} # three days
  end

  defp lease_time(%{"hub.lease_seconds" => lease_seconds}) do
    {:ok, String.to_integer(lease_seconds)}
  end

  defp lease_time(_) do
    {:ok, 60 * 60 * 24 * 3} # three days
  end

  defp valid_topic(%{"hub.topic" => topic}, user) do
    if topic == OStatus.feed_path(user) do
      {:ok, OStatus.feed_path(user)}
    else
      {:error, "Wrong topic requested, expected #{OStatus.feed_path(user)}, got #{topic}"}
    end
  end

  def subscribe(subscriber, subscribed, requester \\ &request_subscription/1) do
    topic = subscribed.info["topic"]
    # FIXME: Race condition, use transactions
    {:ok, subscription} = with subscription when not is_nil(subscription) <- Repo.get_by(WebsubClientSubscription, topic: topic) do
      subscribers = [subscriber.ap_id | subscription.subscribers] |> Enum.uniq
      change = Ecto.Changeset.change(subscription, %{subscribers: subscribers})
      Repo.update(change)
    else _e ->
      subscription = %WebsubClientSubscription{
        topic: topic,
        hub: subscribed.info["hub"],
        subscribers: [subscriber.ap_id],
        state: "requested",
        secret: :crypto.strong_rand_bytes(8) |> Base.url_encode64,
        user: subscribed
      }
      Repo.insert(subscription)
    end
    requester.(subscription)
  end

  def gather_feed_data(topic, getter \\ &@httpoison.get/1) do
    with {:ok, response} <- getter.(topic),
         status_code when status_code in 200..299 <- response.status_code,
         body <- response.body,
         doc <- XML.parse_document(body),
         uri when not is_nil(uri) <- XML.string_from_xpath("/feed/author[1]/uri", doc),
         hub when not is_nil(hub) <- XML.string_from_xpath(~S{/feed/link[@rel="hub"]/@href}, doc) do

      name = XML.string_from_xpath("/feed/author[1]/name", doc)
      preferredUsername = XML.string_from_xpath("/feed/author[1]/poco:preferredUsername", doc)
      displayName = XML.string_from_xpath("/feed/author[1]/poco:displayName", doc)
      avatar = OStatus.make_avatar_object(doc)

      {:ok, %{
        "uri" => uri,
        "hub" => hub,
        "nickname" => preferredUsername || name,
        "name" => displayName || name,
        "host" => URI.parse(uri).host,
        "avatar" => avatar
      }}
    else e ->
      {:error, e}
    end
  end

  def request_subscription(websub, poster \\ &@httpoison.post/3, timeout \\ 10_000) do
    data = [
      "hub.mode": "subscribe",
      "hub.topic": websub.topic,
      "hub.secret": websub.secret,
      "hub.callback": Helpers.websub_url(Endpoint, :websub_subscription_confirmation, websub.id)
    ]

    # This checks once a second if we are confirmed yet
    websub_checker = fn ->
      helper = fn (helper) ->
        :timer.sleep(1000)
        websub = Repo.get_by(WebsubClientSubscription, id: websub.id, state: "accepted")
        if websub, do: websub, else: helper.(helper)
      end
      helper.(helper)
    end

    task = Task.async(websub_checker)

    with {:ok, %{status_code: 202}} <- poster.(websub.hub, {:form, data}, ["Content-type": "application/x-www-form-urlencoded"]),
         {:ok, websub} <- Task.yield(task, timeout) do
      {:ok, websub}
    else e ->
      Task.shutdown(task)

      change = Ecto.Changeset.change(websub, %{state: "rejected"})
      {:ok, websub} = Repo.update(change)

      Logger.debug(fn -> "Couldn't confirm subscription: #{inspect(websub)}" end)
      Logger.debug(fn -> "error: #{inspect(e)}" end)

      {:error, websub}
    end
  end

  def refresh_subscriptions(delta \\ 60 * 60 * 24) do
    Logger.debug("Refreshing subscriptions")

    cut_off = NaiveDateTime.add(NaiveDateTime.utc_now, delta)

    query = from sub in WebsubClientSubscription,
      where: sub.valid_until < ^cut_off and sub.state == "active"

    subs = Repo.all(query)

    Enum.map(subs, fn (sub) ->
      request_subscription(sub)
    end)
  end
end
