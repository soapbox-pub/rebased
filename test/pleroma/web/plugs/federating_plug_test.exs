# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.FederatingPlugTest do
  use Pleroma.Web.ConnCase

  setup do: clear_config([:instance, :federating])

  test "returns and halt the conn when federating is disabled" do
    clear_config([:instance, :federating], false)

    conn =
      build_conn()
      |> Pleroma.Web.Plugs.FederatingPlug.call(%{})

    assert conn.status == 404
    assert conn.halted
  end

  test "does nothing when federating is enabled" do
    clear_config([:instance, :federating], true)

    conn =
      build_conn()
      |> Pleroma.Web.Plugs.FederatingPlug.call(%{})

    refute conn.status
    refute conn.halted
  end
end
