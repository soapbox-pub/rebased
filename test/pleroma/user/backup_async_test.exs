# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.BackupAsyncTest do
  use Pleroma.DataCase, async: true

  import Pleroma.Factory
  import Mox

  alias Pleroma.UnstubbedConfigMock, as: ConfigMock
  alias Pleroma.User.Backup
  alias Pleroma.User.Backup.ProcessorMock

  setup do
    user = insert(:user, %{nickname: "cofe", name: "Cofe", ap_id: "http://cofe.io/users/cofe"})

    {:ok, backup} = user |> Backup.new() |> Repo.insert()
    %{backup: backup}
  end

  @tag capture_log: true
  test "it handles unrecoverable exceptions", %{backup: backup} do
    ProcessorMock
    |> expect(:do_process, fn _, _ ->
      raise "mock exception"
    end)

    ConfigMock
    |> stub_with(Pleroma.Config)

    {:error, %{backup: backup, reason: :exit}} = Backup.process(backup, ProcessorMock)

    assert backup.state == :failed
  end

  @tag capture_log: true
  test "it handles timeouts", %{backup: backup} do
    ProcessorMock
    |> expect(:do_process, fn _, _ ->
      Process.sleep(:timer.seconds(4))
    end)

    ConfigMock
    |> expect(:get, fn [Pleroma.User.Backup, :process_wait_time] -> :timer.seconds(2) end)

    {:error, %{backup: backup, reason: :timeout}} = Backup.process(backup, ProcessorMock)

    assert backup.state == :failed
  end
end
