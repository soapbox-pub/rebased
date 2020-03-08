# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicyTest do
  use Pleroma.DataCase

  alias Pleroma.HTTP
  alias Pleroma.Tests.ObanHelpers
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

  test "it prefetches media proxy URIs" do
    with_mock HTTP, get: fn _, _, _ -> {:ok, []} end do
      MediaProxyWarmingPolicy.filter(@message)

      ObanHelpers.perform_all()
      # Performing jobs which has been just enqueued
      ObanHelpers.perform_all()

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
