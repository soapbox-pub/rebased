defmodule Mix.Tasks.RelayFollow do
  use Mix.Task
  require Logger
  alias Pleroma.Web.ActivityPub.Relay

  @shortdoc "Follows a remote relay"
  @moduledoc """
  Follows a remote relay

  Usage: ``mix relay_follow <relay_url>``

  Example: ``mix relay_follow https://example.org/relay``
  """
  def run([target]) do
    Mix.Task.run("app.start")

    :ok = Relay.follow(target)

    # put this task to sleep to allow the genserver to push out the messages
    :timer.sleep(500)
  end
end
