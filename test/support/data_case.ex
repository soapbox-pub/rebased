# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
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

  import Pleroma.Tests.Helpers, only: [clear_config: 2]

  using do
    quote do
      alias Pleroma.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Pleroma.DataCase
      use Pleroma.Tests.Helpers

      # Sets up OAuth access with specified scopes
      defp oauth_access(scopes, opts \\ []) do
        user =
          Keyword.get_lazy(opts, :user, fn ->
            Pleroma.Factory.insert(:user)
          end)

        token =
          Keyword.get_lazy(opts, :oauth_token, fn ->
            Pleroma.Factory.insert(:oauth_token, user: user, scopes: scopes)
          end)

        %{user: user, token: token}
      end
    end
  end

  def clear_cachex do
    Pleroma.Supervisor
    |> Supervisor.which_children()
    |> Enum.each(fn
      {name, _, _, [Cachex]} ->
        name
        |> to_string
        |> String.trim_leading("cachex_")
        |> Kernel.<>("_cache")
        |> String.to_existing_atom()
        |> Cachex.clear()

      _ ->
        nil
    end)
  end

  def setup_multi_process_mode(tags) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Pleroma.Repo)

    if tags[:async] do
      Mox.stub_with(Pleroma.CachexMock, Pleroma.NullCache)
      Mox.set_mox_private()
    else
      Ecto.Adapters.SQL.Sandbox.mode(Pleroma.Repo, {:shared, self()})

      Mox.set_mox_global()
      Mox.stub_with(Pleroma.CachexMock, Pleroma.CachexProxy)
      clear_cachex()
    end

    :ok
  end

  def setup_streamer(tags) do
    if tags[:needs_streamer] do
      start_supervised(%{
        id: Pleroma.Web.Streamer.registry(),
        start:
          {Registry, :start_link, [[keys: :duplicate, name: Pleroma.Web.Streamer.registry()]]}
      })
    end

    :ok
  end

  setup tags do
    setup_multi_process_mode(tags)
    setup_streamer(tags)
    stub_pipeline()

    Mox.verify_on_exit!()

    :ok
  end

  def stub_pipeline do
    Mox.stub_with(Pleroma.Web.ActivityPub.SideEffectsMock, Pleroma.Web.ActivityPub.SideEffects)

    Mox.stub_with(
      Pleroma.Web.ActivityPub.ObjectValidatorMock,
      Pleroma.Web.ActivityPub.ObjectValidator
    )

    Mox.stub_with(Pleroma.Web.ActivityPub.MRFMock, Pleroma.Web.ActivityPub.MRF)
    Mox.stub_with(Pleroma.Web.ActivityPub.ActivityPubMock, Pleroma.Web.ActivityPub.ActivityPub)
    Mox.stub_with(Pleroma.Web.FederatorMock, Pleroma.Web.Federator)
    Mox.stub_with(Pleroma.ConfigMock, Pleroma.Config)
  end

  def ensure_local_uploader(context) do
    test_uploader = Map.get(context, :uploader) || Pleroma.Uploaders.Local

    clear_config([Pleroma.Upload, :uploader], test_uploader)
    clear_config([Pleroma.Upload, :filters], [])

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
