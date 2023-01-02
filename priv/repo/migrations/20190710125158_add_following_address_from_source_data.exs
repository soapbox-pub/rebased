# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddFollowingAddressFromSourceData do
  alias Pleroma.User
  import Ecto.Query
  require Logger
  use Ecto.Migration

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

      user ->
        Logger.warn("User #{user.id} / #{user.nickname} does not seem to have source_data")
    end)
  end
end
