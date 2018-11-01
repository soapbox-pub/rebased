defmodule Mix.Tasks.RmUser do
  use Mix.Task
  alias Pleroma.User

  @shortdoc "Permanently delete a user"
  def run([nickname]) do
    Mix.Task.run("app.start")

    with %User{local: true} = user <- User.get_by_nickname(nickname) do
      {:ok, _} = User.delete(user)
    end
  end
end
