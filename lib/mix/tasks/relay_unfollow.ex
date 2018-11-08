defmodule Mix.Tasks.RelayUnfollow do
  use Mix.Task
  require Logger
  alias Pleroma.Web.ActivityPub.Relay

  @moduledoc """
  Unfollows a remote relay

  Usage: ``mix relay_follow <relay_url>``

  Example: ``mix relay_follow https://example.org/relay``
  """
  def run([target]) do
    Mix.Task.run("app.start")

    :ok = Relay.unfollow(target)

    # put this task to sleep to allow the genserver to push out the messages
    :timer.sleep(500)
  end
end
