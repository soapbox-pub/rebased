# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Pleroma.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Pleroma.DataCase
      use Pleroma.Tests.Helpers
    end
  end

  setup tags do
    Cachex.clear(:user_cache)
    Cachex.clear(:object_cache)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Pleroma.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Pleroma.Repo, {:shared, self()})
    end

    if tags[:needs_streamer] do
      start_supervised(Pleroma.Web.Streamer.supervisor())
    end

    :ok
  end

  def ensure_local_uploader(context) do
    test_uploader = Map.get(context, :uploader, Pleroma.Uploaders.Local)
    uploader = Pleroma.Config.get([Pleroma.Upload, :uploader])
    filters = Pleroma.Config.get([Pleroma.Upload, :filters])

    Pleroma.Config.put([Pleroma.Upload, :uploader], test_uploader)
    Pleroma.Config.put([Pleroma.Upload, :filters], [])

    on_exit(fn ->
      Pleroma.Config.put([Pleroma.Upload, :uploader], uploader)
      Pleroma.Config.put([Pleroma.Upload, :filters], filters)
    end)

    :ok
  end

  @doc """
  A helper that transform changeset errors to a map of messages.

      changeset = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
