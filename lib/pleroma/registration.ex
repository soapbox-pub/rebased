# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Registration do
  use Ecto.Schema

  import Ecto.Changeset

  alias Pleroma.Registration
  alias Pleroma.Repo
  alias Pleroma.User

  schema "registrations" do
    belongs_to(:user, User, type: Pleroma.FlakeId)
    field(:provider, :string)
    field(:uid, :string)
    field(:info, :map, default: %{})

    timestamps()
  end

  def changeset(registration, params \\ %{}) do
    registration
    |> cast(params, [:user_id, :provider, :uid, :info])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:uid, name: :registrations_provider_uid_index)
  end

  def get_by_provider_uid(provider, uid) do
    Repo.get_by(Registration,
      provider: to_string(provider),
      uid: to_string(uid)
    )
  end
end
