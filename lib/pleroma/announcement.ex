# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Announcement do
  use Ecto.Schema

  import Ecto.Changeset, only: [cast: 3, validate_required: 2]
  import Ecto.Query

  alias Pleroma.AnnouncementReadRelationship
  alias Pleroma.Repo

  @type t :: %__MODULE__{}
  @primary_key {:id, FlakeId.Ecto.CompatType, autogenerate: true}

  schema "announcements" do
    field(:data, :map)
    field(:starts_at, :utc_datetime)
    field(:ends_at, :utc_datetime)
    field(:rendered, :map)

    timestamps(type: :utc_datetime)
  end

  def change(struct, params \\ %{}) do
    struct
    |> cast(validate_params(struct, params), [:data, :starts_at, :ends_at, :rendered])
    |> validate_required([:data])
  end

  defp validate_params(struct, params) do
    base_data =
      %{
        "content" => "",
        "all_day" => false
      }
      |> Map.merge((struct && struct.data) || %{})

    merged_data =
      Map.merge(base_data, params.data)
      |> Map.take(["content", "all_day"])

    params
    |> Map.merge(%{data: merged_data})
    |> add_rendered_properties()
  end

  def add_rendered_properties(params) do
    {content_html, _, _} =
      Pleroma.Web.CommonAPI.Utils.format_input(params.data["content"], "text/plain",
        mentions_format: :full
      )

    rendered = %{
      "content" => content_html
    }

    params
    |> Map.put(:rendered, rendered)
  end

  def add(params) do
    changeset = change(%__MODULE__{}, params)

    Repo.insert(changeset)
  end

  def update(announcement, params) do
    changeset = change(announcement, params)

    Repo.update(changeset)
  end

  def list_all do
    __MODULE__
    |> Repo.all()
  end

  def list_paginated(%{limit: limited_number, offset: offset_number}) do
    __MODULE__
    |> limit(^limited_number)
    |> offset(^offset_number)
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

  def read_by?(announcement, user) do
    AnnouncementReadRelationship.exists?(user, announcement)
  end

  def mark_read_by(announcement, user) do
    AnnouncementReadRelationship.mark_read(user, announcement)
  end

  def render_json(announcement, opts \\ []) do
    extra_params =
      case Keyword.fetch(opts, :for) do
        {:ok, user} when not is_nil(user) ->
          %{read: read_by?(announcement, user)}

        _ ->
          %{}
      end

    admin_extra_params =
      case Keyword.fetch(opts, :admin) do
        {:ok, true} ->
          %{pleroma: %{raw_content: announcement.data["content"]}}

        _ ->
          %{}
      end

    base = %{
      id: announcement.id,
      content: announcement.rendered["content"],
      starts_at: announcement.starts_at,
      ends_at: announcement.ends_at,
      all_day: announcement.data["all_day"],
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
    |> Map.merge(admin_extra_params)
  end

  # "visible" means:
  # starts_at < time < ends_at
  def list_all_visible_when(time) do
    __MODULE__
    |> where([a], is_nil(a.starts_at) or a.starts_at < ^time)
    |> where([a], is_nil(a.ends_at) or a.ends_at > ^time)
    |> Repo.all()
  end

  def list_all_visible do
    list_all_visible_when(DateTime.now("Etc/UTC") |> elem(1))
  end
end
