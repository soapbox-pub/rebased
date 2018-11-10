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

    {status, message} = Relay.unfollow(target)

    if :ok == status do
      # put this task to sleep to allow the genserver to push out the messages
      :timer.sleep(500)
    else
      Mix.puts("Error: #{inspect(message)}")
    end
  end
end
