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
      "hub.mode" => "subscription",
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
      "hub.mode" => "subscription",
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
end
