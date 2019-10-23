# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Marker do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Ecto.Multi
  alias Pleroma.Repo
  alias Pleroma.User
  alias __MODULE__

  @timelines ["notifications"]

  schema "markers" do
    field(:last_read_id, :string, default: "")
    field(:timeline, :string, default: "")
    field(:lock_version, :integer, default: 0)
    field(:unread_count, :integer, default: 0)

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
        on_conflict: {:replace, [:last_read_id, :unread_count]},
        conflict_target: [:user_id, :timeline]
      )
    end)
    |> Repo.transaction()
  end

  @spec multi_set_unread_count(Multi.t(), User.t(), String.t()) :: Multi.t()
  def multi_set_unread_count(multi, %User{} = user, "notifications") do
    multi
    |> Multi.run(:counters, fn _repo, _changes ->
      query =
        from(q in Pleroma.Notification,
          where: q.user_id == ^user.id,
          select: %{
            timeline: "notifications",
            user_id: type(^user.id, :string),
            unread_count: fragment("SUM( CASE WHEN seen = false THEN 1 ELSE 0 END )"),
            last_read_id:
              type(fragment("MAX( CASE WHEN seen = true THEN id ELSE null END )"), :string)
          }
        )

      {:ok, Repo.one(query)}
    end)
    |> Multi.insert(
      :marker,
      fn %{counters: attrs} ->
        Marker
        |> struct(attrs)
        |> Ecto.Changeset.change()
      end,
      returning: true,
      on_conflict: {:replace, [:last_read_id, :unread_count]},
      conflict_target: [:user_id, :timeline]
    )
  end

  def multi_set_unread_count(multi, _, _), do: multi

  defp get_marker(user, timeline) do
    case Repo.find_resource(get_query(user, timeline)) do
      {:ok, marker} -> %__MODULE__{marker | user: user}
      _ -> %__MODULE__{timeline: timeline, user_id: user.id}
    end
  end

  @doc false
  defp changeset(marker, attrs) do
    marker
    |> cast(attrs, [:last_read_id, :unread_count])
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
