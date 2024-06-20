# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

Code.put_compiler_option(:warnings_as_errors, true)

ExUnit.configure(capture_log: true, max_cases: System.schedulers_online())

ExUnit.start(exclude: [:federated])

if match?({:unix, :darwin}, :os.type()) do
  excluded = ExUnit.configuration() |> Keyword.get(:exclude, [])
  excluded = excluded ++ [:skip_darwin]
  ExUnit.configure(exclude: excluded)
end

Ecto.Adapters.SQL.Sandbox.mode(Pleroma.Repo, :manual)

Mox.defmock(Pleroma.ReverseProxy.ClientMock, for: Pleroma.ReverseProxy.Client)
Mox.defmock(Pleroma.GunMock, for: Pleroma.Gun)

{:ok, _} = Application.ensure_all_started(:ex_machina)

ExUnit.after_suite(fn _results ->
  uploads = Pleroma.Config.get([Pleroma.Uploaders.Local, :uploads], "test/uploads")
  File.rm_rf!(uploads)
end)

defmodule Pleroma.Test.StaticConfig do
  @moduledoc """
  This module provides a Config that is completely static, built at startup time from the environment. It's safe to use in testing as it will not modify any state.
  """

  @behaviour Pleroma.Config.Getting
  @config Application.get_all_env(:pleroma)

  def get(path, default \\ nil) do
    get_in(@config, path) || default
  end
end
