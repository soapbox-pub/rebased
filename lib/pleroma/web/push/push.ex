# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Push do
  use GenServer

  alias Pleroma.Web.Push.Impl

  require Logger

  ##############
  # Client API #
  ##############

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def vapid_config() do
    Application.get_env(:web_push_encryption, :vapid_details, [])
  end

  def enabled() do
    case vapid_config() do
      [] -> false
      list when is_list(list) -> true
      _ -> false
    end
  end

  def send(notification),
    do: GenServer.cast(__MODULE__, {:send, notification})

  ####################
  # Server Callbacks #
  ####################

  @impl true
  def init(:ok) do
    if enabled() do
      {:ok, nil}
    else
      Logger.warn("""
      VAPID key pair is not found. If you wish to enabled web push, please run

          mix web_push.gen.keypair

      and add the resulting output to your configuration file.
      """)

      :ignore
    end
  end

  @impl true
  def handle_cast({:send, notification}, state) do
    if enabled() do
      Impl.perform_send(notification)
    end

    {:noreply, state}
  end
end
