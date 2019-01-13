# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FederatingPlugTest do
  use Pleroma.Web.ConnCase

  test "returns and halt the conn when federating is disabled" do
    instance =
      Application.get_env(:pleroma, :instance)
      |> Keyword.put(:federating, false)

    Application.put_env(:pleroma, :instance, instance)

    conn =
      build_conn()
      |> Pleroma.Web.FederatingPlug.call(%{})

    assert conn.status == 404
    assert conn.halted

    instance =
      Application.get_env(:pleroma, :instance)
      |> Keyword.put(:federating, true)

    Application.put_env(:pleroma, :instance, instance)
  end

  test "does nothing when federating is enabled" do
    conn =
      build_conn()
      |> Pleroma.Web.FederatingPlug.call(%{})

    refute conn.status
    refute conn.halted
  end
end
