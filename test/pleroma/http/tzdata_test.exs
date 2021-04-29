# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.TzdataTest do
  use ExUnit.Case

  import Tesla.Mock
  alias Pleroma.HTTP
  @url "https://data.iana.org/time-zones/tzdata-latest.tar.gz"

  setup do
    mock(fn
      %{method: :head, url: @url} ->
        %Tesla.Env{status: 200, body: ""}

      %{method: :get, url: @url} ->
        %Tesla.Env{status: 200, body: "hello"}
    end)

    :ok
  end

  describe "head/1" do
    test "returns successfully result" do
      assert HTTP.Tzdata.head(@url, [], []) == {:ok, {200, []}}
    end
  end

  describe "get/1" do
    test "returns successfully result" do
      assert HTTP.Tzdata.get(@url, [], []) == {:ok, {200, [], "hello"}}
    end
  end
end
