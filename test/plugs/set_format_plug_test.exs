# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.SetFormatPlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Pleroma.Plugs.SetFormatPlug

  test "set format from params" do
    conn =
      :get
      |> conn("/cofe?_format=json")
      |> SetFormatPlug.call([])

    assert %{format: "json"} == conn.assigns
  end

  test "set format from header" do
    conn =
      :get
      |> conn("/cofe")
      |> put_private(:phoenix_format, "xml")
      |> SetFormatPlug.call([])

    assert %{format: "xml"} == conn.assigns
  end

  test "doesn't set format" do
    conn =
      :get
      |> conn("/cofe")
      |> SetFormatPlug.call([])

    refute conn.assigns[:format]
  end
end
