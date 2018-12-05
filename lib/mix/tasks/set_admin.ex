defmodule Mix.Tasks.SetAdmin do
  use Mix.Task
  import Ecto.Changeset
  alias Pleroma.User

  @doc """
  Sets admin status
  Usage: set_admin nickname [true|false]
  """
  def run([nickname | rest]) do
    Application.ensure_all_started(:pleroma)

    admin =
      case rest do
        [admin] -> admin == "true"
        _ -> true
      end

    with %User{local: true} = user <- User.get_by_nickname(nickname) do
      info_cng = User.Info.admin_api_update(user.info, %{is_admin: !!admin})
      user_cng = Ecto.Changeset.change(user)
      |> put_embed(:info, info_cng) 
      {:ok, user} = User.update_and_set_cache(user_cng)

      IO.puts("Admin status of #{nickname}: #{user.info.is_admin}")
    else
      _ ->
        IO.puts("No local user #{nickname}")
    end
  end
end
