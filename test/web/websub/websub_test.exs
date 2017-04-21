defmodule Pleroma.Web.WebsubTest do
  use Pleroma.DataCase
  alias Pleroma.Web.Websub
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

      assert is_number(seconds)

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
    topic = sub.topic

    getter = fn (_path, _headers, _options) ->
      {:ok, %HTTPoison.Response{
        status_code: 500,
        body: ""
      }}
    end

    {:error, sub} = Websub.verify(sub, getter)
    assert sub.state == "rejected"
  end
end
