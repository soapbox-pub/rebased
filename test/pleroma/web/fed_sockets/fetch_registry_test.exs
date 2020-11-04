# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FedSockets.FetchRegistryTest do
  use ExUnit.Case

  alias Pleroma.Web.FedSockets.FetchRegistry
  alias Pleroma.Web.FedSockets.FetchRegistry.FetchRegistryData

  @json_message "hello"
  @json_reply "hello back"

  setup do
    start_supervised(
      {Pleroma.Web.FedSockets.Supervisor,
       [
         ping_interval: 8,
         connection_duration: 15,
         rejection_duration: 5,
         fed_socket_fetches: [default: 10, interval: 10]
       ]}
    )

    :ok
  end

  test "fetches can be stored" do
    uuid = FetchRegistry.register_fetch(@json_message)

    assert {:error, :waiting} = FetchRegistry.check_fetch(uuid)
  end

  test "fetches can return" do
    uuid = FetchRegistry.register_fetch(@json_message)
    task = Task.async(fn -> FetchRegistry.register_fetch_received(uuid, @json_reply) end)

    assert {:error, :waiting} = FetchRegistry.check_fetch(uuid)
    Task.await(task)

    assert {:ok, %FetchRegistryData{received_json: received_json}} =
             FetchRegistry.check_fetch(uuid)

    assert received_json == @json_reply
  end

  test "fetches are deleted once popped from stack" do
    uuid = FetchRegistry.register_fetch(@json_message)
    task = Task.async(fn -> FetchRegistry.register_fetch_received(uuid, @json_reply) end)
    Task.await(task)

    assert {:ok, %FetchRegistryData{received_json: received_json}} =
             FetchRegistry.check_fetch(uuid)

    assert received_json == @json_reply
    assert {:ok, @json_reply} = FetchRegistry.pop_fetch(uuid)

    assert {:error, :missing} = FetchRegistry.check_fetch(uuid)
  end

  test "fetches can time out" do
    uuid = FetchRegistry.register_fetch(@json_message)
    assert {:error, :waiting} = FetchRegistry.check_fetch(uuid)
    Process.sleep(500)
    assert {:error, :missing} = FetchRegistry.check_fetch(uuid)
  end
end
