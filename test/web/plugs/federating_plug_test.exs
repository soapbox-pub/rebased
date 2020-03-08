# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FederatingPlugTest do
  use Pleroma.Web.ConnCase

  clear_config([:instance, :federating])

  test "returns and halt the conn when federating is disabled" do
    Pleroma.Config.put([:instance, :federating], false)

    conn =
      build_conn()
      |> Pleroma.Web.FederatingPlug.call(%{})

    assert conn.status == 404
    assert conn.halted
  end

  test "does nothing when federating is enabled" do
    Pleroma.Config.put([:instance, :federating], true)

    conn =
      build_conn()
      |> Pleroma.Web.FederatingPlug.call(%{})

    refute conn.status
    refute conn.halted
  end
end
