# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HealthcheckTest do
  use Pleroma.DataCase
  alias Pleroma.Healthcheck

  test "system_info/0" do
    result = Healthcheck.system_info() |> Map.from_struct()

    assert Map.keys(result) == [
             :active,
             :healthy,
             :idle,
             :job_queue_stats,
             :memory_used,
             :pool_size
           ]
  end

  describe "check_health/1" do
    test "pool size equals active connections" do
      result = Healthcheck.check_health(%Healthcheck{pool_size: 10, active: 10})
      refute result.healthy
    end

    test "chech_health/1" do
      result = Healthcheck.check_health(%Healthcheck{pool_size: 10, active: 9})
      assert result.healthy
    end
  end
end
