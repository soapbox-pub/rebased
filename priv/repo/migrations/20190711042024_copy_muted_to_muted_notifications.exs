defmodule Pleroma.Repo.Migrations.CopyMutedToMutedNotifications do
  use Ecto.Migration
  import Ecto.Query
  alias Pleroma.User

  def change do
    query = from(u in "users", where: fragment("not (?->'deactivated' @> 'true')", u.info), select: %{info: u.info}, where: u.local == true, order_by: u.id)
    Pleroma.Repo.stream(query)
    |> Enum.each(fn
      %{info: %{mutes: mutes} = info} = user ->
        info_cng =
          Ecto.Changeset.cast(info, %{muted_notifications: mutes}, [:muted_notifications])

        Ecto.Changeset.change(user)
        |> Ecto.Changeset.put_embed(:info, info_cng)
        |> Pleroma.Repo.update()
    end)
  end
end
