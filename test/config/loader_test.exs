# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.LoaderTest do
  use ExUnit.Case, async: true

  alias Pleroma.Config.Loader

  test "load/1" do
    config = Loader.load("test/fixtures/config/temp.secret.exs")
    assert config[:pleroma][:first_setting][:key] == "value"
    assert config[:pleroma][:first_setting][:key2] == [Pleroma.Repo]
    assert config[:quack][:level] == :info
  end

  test "load_and_merge/0" do
    config = Loader.load_and_merge()

    refute config[:pleroma][Pleroma.Repo]
    refute config[:pleroma][Pleroma.Web.Endpoint]
    refute config[:pleroma][:env]
    refute config[:pleroma][:configurable_from_database]
    refute config[:pleroma][:database]
    refute config[:phoenix][:serve_endpoints]

    assert config[:pleroma][:ecto_repos] == [Pleroma.Repo]
    assert config[:pleroma][Pleroma.Uploaders.Local][:uploads] == "test/uploads"
    assert config[:tesla][:adapter] == Tesla.Mock
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
