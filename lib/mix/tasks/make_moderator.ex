defmodule Mix.Tasks.SetModerator do
  use Mix.Task
  import Mix.Ecto
  alias Pleroma.{Repo, User}

  @shortdoc "Set moderator status"
  def run([nickname | rest]) do
    ensure_started(Repo, [])

    moderator = case rest do
                  [moderator] -> moderator == "true"
                  _ -> true
                end

    with %User{local: true} = user <- User.get_by_nickname(nickname) do
      info = user.info
      |> Map.put("is_moderator", !!moderator)
      cng = User.info_changeset(user, %{info: info})
      user = Repo.update!(cng)

      IO.puts "Moderator status of #{nickname}: #{user.info["is_moderator"]}"
    else
      _ ->
        IO.puts "No local user #{nickname}"
    end
  end
end
