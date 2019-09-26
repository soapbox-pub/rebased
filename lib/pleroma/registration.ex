# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Registration do
  use Ecto.Schema

  import Ecto.Changeset

  alias Pleroma.Registration
  alias Pleroma.Repo
  alias Pleroma.User

  @primary_key {:id, FlakeId.Ecto.CompatType, autogenerate: true}

  schema "registrations" do
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    field(:provider, :string)
    field(:uid, :string)
    field(:info, :map, default: %{})

    timestamps()
  end

  def nickname(registration, default \\ nil),
    do: Map.get(registration.info, "nickname", default)

  def email(registration, default \\ nil),
    do: Map.get(registration.info, "email", default)

  def name(registration, default \\ nil),
    do: Map.get(registration.info, "name", default)

  def description(registration, default \\ nil),
    do: Map.get(registration.info, "description", default)

  def changeset(registration, params \\ %{}) do
    registration
    |> cast(params, [:user_id, :provider, :uid, :info])
    |> validate_required([:provider, :uid])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:uid, name: :registrations_provider_uid_index)
  end

  def bind_to_user(registration, user) do
    registration
    |> changeset(%{user_id: (user && user.id) || nil})
    |> Repo.update()
  end

  def get_by_provider_uid(provider, uid) do
    Repo.get_by(Registration,
      provider: to_string(provider),
      uid: to_string(uid)
    )
  end
end
