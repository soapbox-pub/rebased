defmodule Mix.Tasks.RmUser do
  use Mix.Task
  import Mix.Ecto
  alias Pleroma.{User, Repo}

  @shortdoc "Permanently delete a user"
  def run([nickname]) do
    ensure_started(Repo, [])

    with %User{local: true} = user <- User.get_by_nickname(nickname) do
      User.delete(user)
    end
  end
end
