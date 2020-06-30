# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Preload.Providers.StatusNetTest do
  use Pleroma.DataCase
  alias Pleroma.Web.Preload.Providers.StatusNet

  setup do: {:ok, StatusNet.generate_terms(nil)}

  test "it renders the info", %{"/api/statusnet/config.json" => info} do
    assert {:ok, res} = Jason.decode(info)
    assert res["site"]
  end
end
