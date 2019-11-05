defmodule Pleroma.Repo.Migrations.AddFollowingAddressFromSourceData do
  use Ecto.Migration
  import Ecto.Query
  alias Pleroma.User

  def change do
    query =
      User.Query.build(%{
        external: true,
        legacy_active: true,
        order_by: :id
      })
      |> select([u], struct(u, [:id, :ap_id, :info]))

    Pleroma.Repo.stream(query)
    |> Enum.each(fn
      %{info: %{source_data: source_data}} = user ->
        Ecto.Changeset.cast(user, %{following_address: source_data["following"]}, [
          :following_address
        ])
        |> Pleroma.Repo.update()
    end)
  end
end
