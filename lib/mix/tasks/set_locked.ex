defmodule Mix.Tasks.SetLocked do
  use Mix.Task
  import Mix.Ecto
  alias Pleroma.{Repo, User}

  @shortdoc "Set locked status"
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
