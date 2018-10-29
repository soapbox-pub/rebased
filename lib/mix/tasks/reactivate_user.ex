defmodule Mix.Tasks.ReactivateUser do
  use Mix.Task
  alias Pleroma.User

  @shortdoc "Reactivate a user"
  def run([nickname]) do
    Mix.Task.run("app.start")

    with user <- User.get_by_nickname(nickname) do
      User.deactivate(user, false)
    end
  end
end
