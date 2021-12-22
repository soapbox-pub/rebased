# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicyTest do
  use ExUnit.Case
  use Pleroma.Tests.Helpers

  alias Pleroma.HTTP
  alias Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy

  import Mock

  @message %{
    "type" => "Create",
    "object" => %{
      "type" => "Note",
      "content" => "content",
      "attachment" => [
        %{"url" => [%{"href" => "http://example.com/image.jpg"}]}
      ]
    }
  }

  setup do: clear_config([:media_proxy, :enabled], true)

  test "it prefetches media proxy URIs" do
    Tesla.Mock.mock(fn %{method: :get, url: "http://example.com/image.jpg"} ->
      {:ok, %Tesla.Env{status: 200, body: ""}}
    end)

    with_mock HTTP, get: fn _, _, _ -> {:ok, []} end do
      MediaProxyWarmingPolicy.filter(@message)

      assert called(HTTP.get(:_, :_, :_))
    end
  end

  test "it does nothing when no attachments are present" do
    object =
      @message["object"]
      |> Map.delete("attachment")

    message =
      @message
      |> Map.put("object", object)

    with_mock HTTP, get: fn _, _, _ -> {:ok, []} end do
      MediaProxyWarmingPolicy.filter(message)
      refute called(HTTP.get(:_, :_, :_))
    end
  end
end
