# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.LoaderTest do
  use ExUnit.Case, async: true

  alias Pleroma.Config.Loader

  test "read/1" do
    config = Loader.read("test/fixtures/config/temp.secret.exs")
    assert config[:pleroma][:first_setting][:key] == "value"
    assert config[:pleroma][:first_setting][:key2] == [Pleroma.Repo]
    assert config[:quack][:level] == :info
  end

  test "filter_group/2" do
    assert Loader.filter_group(:pleroma,
             pleroma: [
               {Pleroma.Repo, [a: 1, b: 2]},
               {Pleroma.Upload, [a: 1, b: 2]},
               {Pleroma.Web.Endpoint, []},
               env: :test,
               configurable_from_database: true,
               database: []
             ]
           ) == [{Pleroma.Upload, [a: 1, b: 2]}]
  end
end
