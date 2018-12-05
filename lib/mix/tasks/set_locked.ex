defmodule Mix.Tasks.SetLocked do
  @moduledoc """
  Lock a local user

  The local user will then have to manually accept/reject followers. This can also be done by the user into their settings.

  Usage: ``mix set_locked <username>``

  Example: ``mix set_locked lain``
  """

  use Mix.Task
  import Ecto.Changeset
  alias Pleroma.{Repo, User}

  def run([nickname | rest]) do
    Application.ensure_all_started(:pleroma)

    locked =
      case rest do
        [locked] -> locked == "true"
        _ -> true
      end

    with %User{local: true} = user <- User.get_by_nickname(nickname) do
      info_cng = User.Info.profile_update(user.info, %{locked: !!locked})

      user_cng =
        Ecto.Changeset.change(user)
        |> put_embed(:info, info_cng)

      {:ok, user} = User.update_and_set_cache(user_cng)

      IO.puts("Locked status of #{nickname}: #{user.info.locked}")
    else
      _ ->
        IO.puts("No local user #{nickname}")
    end
  end
end
