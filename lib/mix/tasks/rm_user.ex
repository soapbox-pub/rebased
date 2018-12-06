defmodule Mix.Tasks.RmUser do
  use Mix.Task
  alias Pleroma.User

  @moduledoc """
  Permanently deletes a user

  Usage: ``mix rm_user [nickname]``

  Example: ``mix rm_user lain``
  """
  def run([nickname]) do
    Mix.Task.run("app.start")

    with %User{local: true} = user <- User.get_by_nickname(nickname) do
      {:ok, _} = User.delete(user)
    end
  end
end
