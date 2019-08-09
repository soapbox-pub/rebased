# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.WebsubTest do
  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  alias Pleroma.ObanHelpers
  alias Pleroma.Web.Router.Helpers
  alias Pleroma.Web.Websub
  alias Pleroma.Web.Websub.WebsubClientSubscription
  alias Pleroma.Web.Websub.WebsubServerSubscription
  alias Pleroma.Workers.Subscriber, as: SubscriberWorker

  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "a verification of a request that is accepted" do
    sub = insert(:websub_subscription)
    topic = sub.topic

    getter = fn _path, _headers, options ->
      %{
        "hub.challenge": challenge,
        "hub.lease_seconds": seconds,
        "hub.topic": ^topic,
        "hub.mode": "subscribe"
      } = Keyword.get(options, :params)

      assert String.to_integer(seconds) > 0

      {:ok,
       %Tesla.Env{
         status: 200,
         body: challenge
       }}
    end

    {:ok, sub} = Websub.verify(sub, getter)
    assert sub.state == "active"
  end

  test "a verification of a request that doesn't return 200" do
    sub = insert(:websub_subscription)

    getter = fn _path, _headers, _options ->
      {:ok,
       %Tesla.Env{
         status: 500,
         body: ""
       }}
    end

    {:error, sub} = Websub.verify(sub, getter)
    # Keep the current state.
    assert sub.state == "requested"
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

    {:ok, subscription} = Websub.incoming_subscription_request(user, data)
    assert subscription.topic == Pleroma.Web.OStatus.feed_path(user)
    assert subscription.state == "requested"
    assert subscription.secret == "a random secret"
    assert subscription.callback == "http://example.org/sub"
  end

  test "an incoming subscription request for an existing subscription" do
    user = insert(:user)

    sub =
      insert(:websub_subscription, state: "accepted", topic: Pleroma.Web.OStatus.feed_path(user))

    data = %{
      "hub.callback" => sub.callback,
      "hub.mode" => "subscribe",
      "hub.topic" => Pleroma.Web.OStatus.feed_path(user),
      "hub.secret" => "a random secret",
      "hub.lease_seconds" => "100"
    }

    {:ok, subscription} = Websub.incoming_subscription_request(user, data)
    assert subscription.topic == Pleroma.Web.OStatus.feed_path(user)
    assert subscription.state == sub.state
    assert subscription.secret == "a random secret"
    assert subscription.callback == sub.callback
    assert length(Repo.all(WebsubServerSubscription)) == 1
    assert subscription.id == sub.id
  end

  def accepting_verifier(subscription) do
    {:ok, %{subscription | state: "accepted"}}
  end

  test "initiate a subscription for a given user and topic" do
    subscriber = insert(:user)
    user = insert(:user, %{info: %Pleroma.User.Info{topic: "some_topic", hub: "some_hub"}})

    {:ok, websub} = Websub.subscribe(subscriber, user, &accepting_verifier/1)
    assert websub.subscribers == [subscriber.ap_id]
    assert websub.topic == "some_topic"
    assert websub.hub == "some_hub"
    assert is_binary(websub.secret)
    assert websub.user == user
    assert websub.state == "accepted"
  end

  test "discovers the hub and canonical url" do
    topic = "https://mastodon.social/users/lambadalambda.atom"

    {:ok, discovered} = Websub.gather_feed_data(topic)

    expected = %{
      "hub" => "https://mastodon.social/api/push",
      "uri" => "https://mastodon.social/users/lambadalambda",
      "nickname" => "lambadalambda",
      "name" => "Critical Value",
      "host" => "mastodon.social",
      "bio" => "a cool dude.",
      "avatar" => %{
        "type" => "Image",
        "url" => [
          %{
            "href" =>
              "https://files.mastodon.social/accounts/avatars/000/000/264/original/1429214160519.gif?1492379244",
            "mediaType" => "image/gif",
            "type" => "Link"
          }
        ]
      }
    }

    assert expected == discovered
  end

  test "calls the hub, requests topic" do
    hub = "https://social.heldscal.la/main/push/hub"
    topic = "https://social.heldscal.la/api/statuses/user_timeline/23211.atom"
    websub = insert(:websub_client_subscription, %{hub: hub, topic: topic})

    poster = fn ^hub, {:form, data}, _headers ->
      assert Keyword.get(data, :"hub.mode") == "subscribe"

      assert Keyword.get(data, :"hub.callback") ==
               Helpers.websub_url(
                 Pleroma.Web.Endpoint,
                 :websub_subscription_confirmation,
                 websub.id
               )

      {:ok, %{status: 202}}
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

    poster = fn ^hub, {:form, _data}, _headers ->
      {:ok, %{status: 202}}
    end

    {:error, websub} = Websub.request_subscription(websub, poster, 1000)
    assert websub.state == "rejected"

    websub = insert(:websub_client_subscription, %{hub: hub, topic: topic})

    poster = fn ^hub, {:form, _data}, _headers ->
      {:ok, %{status: 400}}
    end

    {:error, websub} = Websub.request_subscription(websub, poster, 1000)
    assert websub.state == "rejected"
  end

  test "sign a text" do
    signed = Websub.sign("secret", "text")
    assert signed == "B8392C23690CCF871F37EC270BE1582DEC57A503" |> String.downcase()

    _signed = Websub.sign("secret", [["て"], ['す']])
  end

  describe "renewing subscriptions" do
    test "it renews subscriptions that have less than a day of time left" do
      day = 60 * 60 * 24
      now = NaiveDateTime.utc_now()

      still_good =
        insert(:websub_client_subscription, %{
          valid_until: NaiveDateTime.add(now, 2 * day),
          topic: "http://example.org/still_good",
          hub: "http://example.org/still_good",
          state: "accepted"
        })

      needs_refresh =
        insert(:websub_client_subscription, %{
          valid_until: NaiveDateTime.add(now, day - 100),
          topic: "http://example.org/needs_refresh",
          hub: "http://example.org/needs_refresh",
          state: "accepted"
        })

      _refresh = Websub.refresh_subscriptions()
      ObanHelpers.perform(all_enqueued(worker: SubscriberWorker))

      assert still_good == Repo.get(WebsubClientSubscription, still_good.id)
      refute needs_refresh == Repo.get(WebsubClientSubscription, needs_refresh.id)
    end
  end
end
