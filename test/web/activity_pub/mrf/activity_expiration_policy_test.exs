# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.ActivityExpirationPolicyTest do
  use ExUnit.Case, async: true
  alias Pleroma.Web.ActivityPub.MRF.ActivityExpirationPolicy

  @id Pleroma.Web.Endpoint.url() <> "/activities/cofe"

  test "adds `expires_at` property" do
    assert {:ok, %{"expires_at" => expires_at}} = ActivityExpirationPolicy.filter(%{"id" => @id})

    assert Timex.diff(expires_at, NaiveDateTime.utc_now(), :days) == 364
  end

  test "keeps existing `expires_at` if it less than the config setting" do
    expires_at = NaiveDateTime.utc_now() |> Timex.shift(days: 1)

    assert {:ok, %{"expires_at" => ^expires_at}} =
             ActivityExpirationPolicy.filter(%{"id" => @id, "expires_at" => expires_at})
  end

  test "overwrites existing `expires_at` if it greater than the config setting" do
    too_distant_future = NaiveDateTime.utc_now() |> Timex.shift(years: 2)

    assert {:ok, %{"expires_at" => expires_at}} =
             ActivityExpirationPolicy.filter(%{"id" => @id, "expires_at" => too_distant_future})

    assert Timex.diff(expires_at, NaiveDateTime.utc_now(), :days) == 364
  end

  test "ignores remote activities" do
    assert {:ok, activity} = ActivityExpirationPolicy.filter(%{"id" => "https://example.com/123"})

    refute Map.has_key?(activity, "expires_at")
  end
end
