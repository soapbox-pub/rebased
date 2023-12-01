# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule User do
  use Ecto.Schema

  schema "users" do
    field(:keys, :string)
    field(:local, :boolean, default: true)
  end
end

defmodule Pleroma.Repo.Migrations.GenerateUnsetUserKeys do
  use Ecto.Migration
  import Ecto.Query
  alias Pleroma.Keys
  alias Pleroma.Repo

  def change do
    query =
      from(u in User,
        where: u.local == true,
        where: is_nil(u.keys),
        select: struct(u, [:id, :keys])
      )

    Repo.stream(query)
    |> Enum.each(fn user ->
      with {:ok, pem} <- Keys.generate_rsa_pem() do
        Ecto.Changeset.cast(user, %{keys: pem}, [:keys])
        |> Repo.update()
      end
    end)
  end
end
