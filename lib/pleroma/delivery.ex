# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Delivery do
  use Ecto.Schema

  alias Pleroma.Delivery
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.User

  import Ecto.Changeset
  import Ecto.Query

  schema "deliveries" do
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:object, Object)
  end

  def changeset(delivery, params \\ %{}) do
    delivery
    |> cast(params, [:user_id, :object_id])
    |> validate_required([:user_id, :object_id])
    |> foreign_key_constraint(:object_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:user_id, name: :deliveries_user_id_object_id_index)
  end

  def create(object_id, user_id) do
    %Delivery{}
    |> changeset(%{user_id: user_id, object_id: object_id})
    |> Repo.insert(on_conflict: :nothing)
  end

  def get(object_id, user_id) do
    from(d in Delivery, where: d.user_id == ^user_id and d.object_id == ^object_id)
    |> Repo.one()
  end

  # A hack because user delete activities have a fake id for whatever reason
  # TODO: Get rid of this
  def delete_all_by_object_id("pleroma:fake_object_id"), do: {0, []}

  def delete_all_by_object_id(object_id) do
    from(d in Delivery, where: d.object_id == ^object_id)
    |> Repo.delete_all()
  end
end
