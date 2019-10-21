# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Relay do
  use Mix.Task
  import Mix.Pleroma
  alias Pleroma.Web.ActivityPub.Relay

  @shortdoc "Manages remote relays"
  @moduledoc File.read!("docs/administration/CLI_tasks/relay.md")

  def run(["follow", target]) do
    start_pleroma()

    with {:ok, _activity} <- Relay.follow(target) do
      # put this task to sleep to allow the genserver to push out the messages
      :timer.sleep(500)
    else
      {:error, e} -> shell_error("Error while following #{target}: #{inspect(e)}")
    end
  end

  def run(["unfollow", target]) do
    start_pleroma()

    with {:ok, _activity} <- Relay.unfollow(target) do
      # put this task to sleep to allow the genserver to push out the messages
      :timer.sleep(500)
    else
      {:error, e} -> shell_error("Error while following #{target}: #{inspect(e)}")
    end
  end

  def run(["list"]) do
    start_pleroma()

    with {:ok, list} <- Relay.list() do
      list |> Enum.each(&shell_info(&1))
    else
      {:error, e} -> shell_error("Error while fetching relay subscription list: #{inspect(e)}")
    end
  end
end
