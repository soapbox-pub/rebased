# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.WebPushTest do
  use ExUnit.Case

  import Tesla.Mock
  alias Pleroma.HTTP

  @push_url "https://some-push-server/"

  setup do
    mock(fn
      %{
        method: :post,
        url: @push_url,
        headers: headers
      } ->
        if {"content-type", "octet-stream"} in headers do
          %Tesla.Env{
            status: 200
          }
        else
          %Tesla.Env{
            status: 403
          }
        end
    end)

    :ok
  end

  test "post" do
    response =
      HTTP.WebPush.post(
        @push_url,
        "encrypted payload",
        %{"authorization" => "WebPush"},
        []
      )

    assert {:ok, %{status: 200}} = response
  end
end
