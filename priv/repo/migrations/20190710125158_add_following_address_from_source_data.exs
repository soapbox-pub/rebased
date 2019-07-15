defmodule Pleroma.Repo.Migrations.AddFollowingAddressFromSourceData do
  use Ecto.Migration
  import Ecto.Query
  alias Pleroma.User

  def change do
    query =
      User.external_users_query()
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
