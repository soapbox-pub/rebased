defmodule Mix.Tasks.ReactivateUser do
  use Mix.Task
  alias Pleroma.User

  @moduledoc """
  Reactivate a user

  Usage: ``mix reactivate_user <nickname>``

  Example: ``mix reactivate_user lain``
  """
  def run([nickname]) do
    Mix.Task.run("app.start")

    with user <- User.get_by_nickname(nickname) do
      User.deactivate(user, false)
    end
  end
end
