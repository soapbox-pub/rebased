# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.MovePinnedActivitiesIntoPinnedObjects do
  use Ecto.Migration

  import Ecto.Query

  alias Pleroma.Repo
  alias Pleroma.Repo.Migrations.AddAssociatedObjectIdFunction
  alias Pleroma.User

  def up do
    # This migration will crash unless `associated_object_id` is already available.
    # https://gitlab.com/soapbox-pub/rebased/-/issues/113
    AddAssociatedObjectIdFunction.up()

    from(u in User)
    |> select([u], {u.id, fragment("?.pinned_activities", u)})
    |> Repo.stream()
    |> Stream.each(fn {user_id, pinned_activities_ids} ->
      pinned_activities = Pleroma.Activity.all_by_ids_with_object(pinned_activities_ids)

      pins =
        Map.new(pinned_activities, fn %{object: %{data: %{"id" => object_id}}} ->
          {object_id, NaiveDateTime.utc_now()}
        end)

      from(u in User, where: u.id == ^user_id)
      |> Repo.update_all(set: [pinned_objects: pins])
    end)
    |> Stream.run()
  end

  def down do
    AddAssociatedObjectIdFunction.down()
  end
end
