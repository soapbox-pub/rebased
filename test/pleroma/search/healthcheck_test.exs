# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Search.HealthcheckTest do
  use Pleroma.DataCase

  import Tesla.Mock

  alias Pleroma.Search.Healthcheck

  @good1 "http://good1.example.com/healthz"
  @good2 "http://good2.example.com/health"
  @bad "http://bad.example.com/healthy"

  setup do
    mock(fn
      %{method: :get, url: @good1} ->
        %Tesla.Env{
          status: 200,
          body: ""
        }

      %{method: :get, url: @good2} ->
        %Tesla.Env{
          status: 200,
          body: ""
        }

      %{method: :get, url: @bad} ->
        %Tesla.Env{
          status: 503,
          body: ""
        }
    end)

    :ok
  end

  test "true for 200 responses" do
    assert Healthcheck.check([@good1])
    assert Healthcheck.check([@good1, @good2])
  end

  test "false if any response is not a 200" do
    refute Healthcheck.check([@bad])
    refute Healthcheck.check([@good1, @bad])
  end
end
