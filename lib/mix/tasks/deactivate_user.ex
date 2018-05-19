defmodule Mix.Tasks.DeactivateUser do
  use Mix.Task
  alias Pleroma.User

  @shortdoc "Toggle deactivation status for a user"
  def run([nickname]) do
    Mix.Task.run("app.start")

    with user <- User.get_by_nickname(nickname) do
      User.deactivate(user)
    end
  end
end
