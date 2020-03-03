# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.CacheTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Pleroma.Plugs.Cache

  @miss_resp {200,
              [
                {"cache-control", "max-age=0, private, must-revalidate"},
                {"content-type", "cofe/hot; charset=utf-8"},
                {"x-cache", "MISS from Pleroma"}
              ], "cofe"}

  @hit_resp {200,
             [
               {"cache-control", "max-age=0, private, must-revalidate"},
               {"content-type", "cofe/hot; charset=utf-8"},
               {"x-cache", "HIT from Pleroma"}
             ], "cofe"}

  @ttl 5

  setup do
    Cachex.clear(:web_resp_cache)
    :ok
  end

  test "caches a response" do
    assert @miss_resp ==
             conn(:get, "/")
             |> Cache.call(%{query_params: false, ttl: nil})
             |> put_resp_content_type("cofe/hot")
             |> send_resp(:ok, "cofe")
             |> sent_resp()

    assert_raise(Plug.Conn.AlreadySentError, fn ->
      conn(:get, "/")
      |> Cache.call(%{query_params: false, ttl: nil})
      |> put_resp_content_type("cofe/hot")
      |> send_resp(:ok, "cofe")
      |> sent_resp()
    end)

    assert @hit_resp ==
             conn(:get, "/")
             |> Cache.call(%{query_params: false, ttl: nil})
             |> sent_resp()
  end

  test "ttl is set" do
    assert @miss_resp ==
             conn(:get, "/")
             |> Cache.call(%{query_params: false, ttl: @ttl})
             |> put_resp_content_type("cofe/hot")
             |> send_resp(:ok, "cofe")
             |> sent_resp()

    assert @hit_resp ==
             conn(:get, "/")
             |> Cache.call(%{query_params: false, ttl: @ttl})
             |> sent_resp()

    :timer.sleep(@ttl + 1)

    assert @miss_resp ==
             conn(:get, "/")
             |> Cache.call(%{query_params: false, ttl: @ttl})
             |> put_resp_content_type("cofe/hot")
             |> send_resp(:ok, "cofe")
             |> sent_resp()
  end

  test "set ttl via conn.assigns" do
    assert @miss_resp ==
             conn(:get, "/")
             |> Cache.call(%{query_params: false, ttl: nil})
             |> put_resp_content_type("cofe/hot")
             |> assign(:cache_ttl, @ttl)
             |> send_resp(:ok, "cofe")
             |> sent_resp()

    assert @hit_resp ==
             conn(:get, "/")
             |> Cache.call(%{query_params: false, ttl: nil})
             |> sent_resp()

    :timer.sleep(@ttl + 1)

    assert @miss_resp ==
             conn(:get, "/")
             |> Cache.call(%{query_params: false, ttl: nil})
             |> put_resp_content_type("cofe/hot")
             |> send_resp(:ok, "cofe")
             |> sent_resp()
  end

  test "ignore query string when `query_params` is false" do
    assert @miss_resp ==
             conn(:get, "/?cofe")
             |> Cache.call(%{query_params: false, ttl: nil})
             |> put_resp_content_type("cofe/hot")
             |> send_resp(:ok, "cofe")
             |> sent_resp()

    assert @hit_resp ==
             conn(:get, "/?cofefe")
             |> Cache.call(%{query_params: false, ttl: nil})
             |> sent_resp()
  end

  test "take query string into account when `query_params` is true" do
    assert @miss_resp ==
             conn(:get, "/?cofe")
             |> Cache.call(%{query_params: true, ttl: nil})
             |> put_resp_content_type("cofe/hot")
             |> send_resp(:ok, "cofe")
             |> sent_resp()

    assert @miss_resp ==
             conn(:get, "/?cofefe")
             |> Cache.call(%{query_params: true, ttl: nil})
             |> put_resp_content_type("cofe/hot")
             |> send_resp(:ok, "cofe")
             |> sent_resp()
  end

  test "take specific query params into account when `query_params` is list" do
    assert @miss_resp ==
             conn(:get, "/?a=1&b=2&c=3&foo=bar")
             |> fetch_query_params()
             |> Cache.call(%{query_params: ["a", "b", "c"], ttl: nil})
             |> put_resp_content_type("cofe/hot")
             |> send_resp(:ok, "cofe")
             |> sent_resp()

    assert @hit_resp ==
             conn(:get, "/?bar=foo&c=3&b=2&a=1")
             |> fetch_query_params()
             |> Cache.call(%{query_params: ["a", "b", "c"], ttl: nil})
             |> sent_resp()

    assert @miss_resp ==
             conn(:get, "/?bar=foo&c=3&b=2&a=2")
             |> fetch_query_params()
             |> Cache.call(%{query_params: ["a", "b", "c"], ttl: nil})
             |> put_resp_content_type("cofe/hot")
             |> send_resp(:ok, "cofe")
             |> sent_resp()
  end

  test "ignore not GET requests" do
    expected =
      {200,
       [
         {"cache-control", "max-age=0, private, must-revalidate"},
         {"content-type", "cofe/hot; charset=utf-8"}
       ], "cofe"}

    assert expected ==
             conn(:post, "/")
             |> Cache.call(%{query_params: true, ttl: nil})
             |> put_resp_content_type("cofe/hot")
             |> send_resp(:ok, "cofe")
             |> sent_resp()
  end

  test "ignore non-successful responses" do
    expected =
      {418,
       [
         {"cache-control", "max-age=0, private, must-revalidate"},
         {"content-type", "tea/iced; charset=utf-8"}
       ], "🥤"}

    assert expected ==
             conn(:get, "/cofe")
             |> Cache.call(%{query_params: true, ttl: nil})
             |> put_resp_content_type("tea/iced")
             |> send_resp(:im_a_teapot, "🥤")
             |> sent_resp()
  end
end
