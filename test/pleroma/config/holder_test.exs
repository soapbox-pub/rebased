# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.HolderTest do
  use ExUnit.Case, async: true

  alias Pleroma.Config.Holder

  test "default_config/0" do
    config = Holder.default_config()
    assert config[:pleroma][Pleroma.Uploaders.Local][:uploads] == "test/uploads"

    refute config[:pleroma][Pleroma.Repo]
    refute config[:pleroma][Pleroma.Web.Endpoint]
    refute config[:pleroma][:env]
    refute config[:pleroma][:configurable_from_database]
    refute config[:pleroma][:database]
    refute config[:phoenix][:serve_endpoints]
    refute config[:tesla][:adapter]
  end

  test "default_config/1" do
    pleroma_config = Holder.default_config(:pleroma)
    assert pleroma_config[Pleroma.Uploaders.Local][:uploads] == "test/uploads"
  end

  test "default_config/2" do
    assert Holder.default_config(:pleroma, Pleroma.Uploaders.Local) == [uploads: "test/uploads"]
  end
end
