defmodule Pleroma.Web.WebsubMock do
  def verify(sub) do
    {:ok, sub}
  end
end

defmodule Pleroma.Web.WebsubTest do
  use Pleroma.DataCase
  alias Pleroma.Web.Websub
  alias Pleroma.Web.Websub.WebsubServerSubscription
  import Pleroma.Factory
  alias Pleroma.Web.Router.Helpers

  test "a verification of a request that is accepted" do
    sub = insert(:websub_subscription)
    topic = sub.topic

    getter = fn (_path, _headers, options) ->
      %{
        "hub.challenge": challenge,
        "hub.lease_seconds": seconds,
        "hub.topic": ^topic,
        "hub.mode": "subscribe"
      } = Keyword.get(options, :params)

      assert String.to_integer(seconds) > 0

      {:ok, %HTTPoison.Response{
        status_code: 200,
        body: challenge
      }}
    end

    {:ok, sub} = Websub.verify(sub, getter)
    assert sub.state == "active"
  end

  test "a verification of a request that doesn't return 200" do
    sub = insert(:websub_subscription)

    getter = fn (_path, _headers, _options) ->
      {:ok, %HTTPoison.Response{
        status_code: 500,
        body: ""
      }}
    end

    {:error, sub} = Websub.verify(sub, getter)
    assert sub.state == "rejected"
  end

  test "an incoming subscription request" do
    user = insert(:user)

    data = %{
      "hub.callback" => "http://example.org/sub",
      "hub.mode" => "subscribe",
      "hub.topic" => Pleroma.Web.OStatus.feed_path(user),
      "hub.secret" => "a random secret",
      "hub.lease_seconds" => "100"
    }

    {:ok, subscription } = Websub.incoming_subscription_request(user, data)
    assert subscription.topic == Pleroma.Web.OStatus.feed_path(user)
    assert subscription.state == "requested"
    assert subscription.secret == "a random secret"
    assert subscription.callback == "http://example.org/sub"
  end

  test "an incoming subscription request for an existing subscription" do
    user = insert(:user)
    sub = insert(:websub_subscription, state: "accepted", topic: Pleroma.Web.OStatus.feed_path(user))

    data = %{
      "hub.callback" => sub.callback,
      "hub.mode" => "subscribe",
      "hub.topic" => Pleroma.Web.OStatus.feed_path(user),
      "hub.secret" => "a random secret",
      "hub.lease_seconds" => "100"
    }

    {:ok, subscription } = Websub.incoming_subscription_request(user, data)
    assert subscription.topic == Pleroma.Web.OStatus.feed_path(user)
    assert subscription.state == sub.state
    assert subscription.secret == "a random secret"
    assert subscription.callback == sub.callback
    assert length(Repo.all(WebsubServerSubscription)) == 1
    assert subscription.id == sub.id
  end

  def accepting_verifier(subscription) do
    {:ok, %{ subscription | state: "accepted" }}
  end

  test "initiate a subscription for a given user and topic" do
    user = insert(:user)
    topic = "http://example.org/some-topic.atom"

    {:ok, websub} = Websub.subscribe(user, topic, &accepting_verifier/1)
    assert websub.subscribers == [user.ap_id]
    assert websub.topic == topic
    assert is_binary(websub.secret)
    assert websub.user == user
    assert websub.state == "accepted"
  end

  test "discovers the hub and canonical url" do
    topic = "https://mastodon.social/users/lambadalambda.atom"

    getter = fn(^topic) ->
      doc = File.read!("test/fixtures/lambadalambda.atom")
      {:ok, %{status_code: 200, body: doc}}
    end

    {:ok, discovered} = Websub.discover(topic, getter)
    assert %{hub: "https://mastodon.social/api/push", url: topic} == discovered
  end

  test "calls the hub, requests topic" do
    hub = "https://social.heldscal.la/main/push/hub"
    topic = "https://social.heldscal.la/api/statuses/user_timeline/23211.atom"
    websub = insert(:websub_client_subscription, %{hub: hub, topic: topic})

    poster = fn (^hub, {:form, data}, _headers) ->
      assert Keyword.get(data, :"hub.mode") == "subscribe"
      assert Keyword.get(data, :"hub.callback") == Helpers.websub_url(Pleroma.Web.Endpoint, :websub_subscription_confirmation, websub.id)
      {:ok, %{status_code: 202}}
    end

    task = Task.async(fn -> Websub.request_subscription(websub, poster) end)

    change = Ecto.Changeset.change(websub, %{state: "accepted"})
    {:ok, _} = Repo.update(change)

    {:ok, websub} = Task.await(task)

    assert websub.state == "accepted"
  end

  test "rejects the subscription if it can't be accepted" do
    hub = "https://social.heldscal.la/main/push/hub"
    topic = "https://social.heldscal.la/api/statuses/user_timeline/23211.atom"
    websub = insert(:websub_client_subscription, %{hub: hub, topic: topic})

    poster = fn (^hub, {:form, _data}, _headers) ->
      {:ok, %{status_code: 202}}
    end

    {:error, websub} = Websub.request_subscription(websub, poster, 1000)
    assert websub.state == "rejected"

    websub = insert(:websub_client_subscription, %{hub: hub, topic: topic})
    poster = fn (^hub, {:form, _data}, _headers) ->
      {:ok, %{status_code: 400}}
    end

    {:error, websub} = Websub.request_subscription(websub, poster, 1000)
    assert websub.state == "rejected"
  end
end
