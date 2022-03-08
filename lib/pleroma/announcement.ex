# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Announcement do
  use Ecto.Schema

  import Ecto.Changeset, only: [cast: 3, validate_required: 2]

  alias Pleroma.Repo

  @type t :: %__MODULE__{}
  @primary_key {:id, FlakeId.Ecto.CompatType, autogenerate: true}

  schema "announcements" do
    field(:data, :map)

    timestamps()
  end

  def change(struct, params \\ %{}) do
    struct
    |> cast(params, [:data])
    |> validate_required([:data])
  end

  def add(params) do
    changeset = change(%__MODULE__{}, params)

    Repo.insert(changeset)
  end

  def list_all do
    __MODULE__
    |> Repo.all()
  end

  def get_by_id(id) do
    Repo.get_by(__MODULE__, id: id)
  end

  def delete_by_id(id) do
    with announcement when not is_nil(announcement) <- get_by_id(id),
         {:ok, _} <- Repo.delete(announcement) do
      :ok
    else
      _ ->
        :error
    end
  end

  def read_by?(_announcement, _user) do
    false
  end

  def render_json(announcement, opts \\ []) do
    extra_params =
      case Keyword.fetch(opts, :for) do
        {:ok, user} ->
          %{read: read_by?(announcement, user)}
        _ ->
          %{}
      end

    base = %{
      id: announcement.id,
      content: announcement.data["content"],
      starts_at: :null,
      ends_at: :null,
      all_day: false,
      published_at: announcement.inserted_at,
      updated_at: announcement.updated_at,
      mentions: [],
      statuses: [],
      tags: [],
      emojis: [],
      reactions: []
    }

    base
    |> Map.merge(extra_params)
  end
end
