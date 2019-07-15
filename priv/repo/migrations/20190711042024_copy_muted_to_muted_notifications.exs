defmodule Pleroma.Repo.Migrations.CopyMutedToMutedNotifications do
  use Ecto.Migration
  alias Pleroma.User

  def change do
    query =
      User.Query.build(%{
        local: true,
        active: true,
        order_by: :id
      })

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
