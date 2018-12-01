defmodule Mix.Tasks.SetAdmin do
  use Mix.Task
  alias Pleroma.User

  @doc """
  Sets admin status
  Usage: set_admin nickname [true|false]
  """
  def run([nickname | rest]) do
    Application.ensure_all_started(:pleroma)

    status =
      case rest do
        [status] -> status == "true"
        _ -> true
      end

    with %User{local: true} = user <- User.get_by_nickname(nickname) do
      info =
        user.info
        |> Map.put("is_admin", !!status)

      cng = User.info_changeset(user, %{info: info})
      {:ok, user} = User.update_and_set_cache(cng)

      IO.puts("Admin status of #{nickname}: #{user.info["is_admin"]}")
    else
      _ ->
        IO.puts("No local user #{nickname}")
    end
  end
end
