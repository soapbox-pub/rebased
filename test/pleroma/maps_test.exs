# Pleroma: A lightweight social networking server
# Copyright © 2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MapsTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Maps

  describe "filter_empty_values/1" do
    assert %{"bar" => "b", "ray" => ["foo"], "objs" => %{"a" => "b"}} ==
             Maps.filter_empty_values(%{
               "foo" => nil,
               "fooz" => "",
               "bar" => "b",
               "rei" => [],
               "ray" => ["foo"],
               "obj" => %{},
               "objs" => %{"a" => "b"}
             })
  end
end
