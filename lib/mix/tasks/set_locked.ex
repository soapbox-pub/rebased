defmodule Mix.Tasks.SetLocked do
  @moduledoc """
  Lock a local user

  The local user will then have to manually accept/reject followers. This can also be done by the user into their settings.

  Usage: ``mix set_locked <username>``

  Example: ``mix set_locked lain``
  """

  use Mix.Task
  import Mix.Ecto
  alias Pleroma.{Repo, User}

  def run([nickname | rest]) do
    ensure_started(Repo, [])

    locked =
      case rest do
        [locked] -> locked == "true"
        _ -> true
      end

    with %User{local: true} = user <- User.get_by_nickname(nickname) do
      info =
        user.info
        |> Map.put("locked", !!locked)

      cng = User.info_changeset(user, %{info: info})
      user = Repo.update!(cng)

      IO.puts("locked status of #{nickname}: #{user.info["locked"]}")
    else
      _ ->
        IO.puts("No local user #{nickname}")
    end
  end
end
