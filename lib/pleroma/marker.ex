# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Marker do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Ecto.Multi
  alias Pleroma.Repo
  alias Pleroma.User

  @timelines ["notifications"]

  schema "markers" do
    field(:last_read_id, :string, default: "")
    field(:timeline, :string, default: "")
    field(:lock_version, :integer, default: 0)

    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    timestamps()
  end

  def get_markers(user, timelines \\ []) do
    Repo.all(get_query(user, timelines))
  end

  def upsert(%User{} = user, attrs) do
    attrs
    |> Map.take(@timelines)
    |> Enum.reduce(Multi.new(), fn {timeline, timeline_attrs}, multi ->
      marker =
        user
        |> get_marker(timeline)
        |> changeset(timeline_attrs)

      Multi.insert(multi, timeline, marker,
        returning: true,
        on_conflict: {:replace, [:last_read_id]},
        conflict_target: [:user_id, :timeline]
      )
    end)
    |> Repo.transaction()
  end

  defp get_marker(user, timeline) do
    case Repo.find_resource(get_query(user, timeline)) do
      {:ok, marker} -> %__MODULE__{marker | user: user}
      _ -> %__MODULE__{timeline: timeline, user_id: user.id}
    end
  end

  @doc false
  defp changeset(marker, attrs) do
    marker
    |> cast(attrs, [:last_read_id])
    |> validate_required([:user_id, :timeline, :last_read_id])
    |> validate_inclusion(:timeline, @timelines)
  end

  defp by_timeline(query, timeline) do
    from(m in query, where: m.timeline in ^List.wrap(timeline))
  end

  defp by_user_id(query, id), do: from(m in query, where: m.user_id == ^id)

  defp get_query(user, timelines) do
    __MODULE__
    |> by_user_id(user.id)
    |> by_timeline(timelines)
  end
end
