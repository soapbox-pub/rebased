defmodule Mix.Tasks.SetModerator do
  @moduledoc """
  Set moderator to a local user

  Usage: ``mix set_moderator <nickname>``

  Example: ``mix set_moderator lain``
  """

  use Mix.Task
  import Ecto.Changeset
  alias Pleroma.{Repo, User}

  def run([nickname | rest]) do
    Application.ensure_all_started(:pleroma)

    moderator =
      case rest do
        [moderator] -> moderator == "true"
        _ -> true
      end

    with %User{local: true} = user <- User.get_by_nickname(nickname) do
      info_cng = User.Info.admin_api_update(user.info, %{is_moderator: !!moderator})
      user_cng = Ecto.Changeset.change(user)
      |> put_embed(:info, info_cng) 
      {:ok, user} = User.update_and_set_cache(user_cng)

      IO.puts("Moderator status of #{nickname}: #{user.info.is_moderator}")
    else
      _ ->
        IO.puts("No local user #{nickname}")
    end
  end
end
