defmodule Mix.Tasks.DeactivateUser do
  use Mix.Task
  alias Pleroma.User

  @moduledoc """
  Deactivates a user (local or remote)

  Usage: ``mix deactivate_user <nickname>``

  Example: ``mix deactivate_user lain``
  """
  def run([nickname]) do
    Mix.Task.run("app.start")

    with user <- User.get_by_nickname(nickname) do
      User.deactivate(user)
    end
  end
end
