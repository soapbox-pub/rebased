# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ThreadMute do
  use Ecto.Schema

  alias Pleroma.Repo
  alias Pleroma.ThreadMute
  alias Pleroma.User

  import Ecto.Changeset
  import Ecto.Query

  schema "thread_mutes" do
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    field(:context, :string)
  end

  def changeset(mute, params \\ %{}) do
    mute
    |> cast(params, [:user_id, :context])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:user_id, name: :unique_index)
  end

  def query(user_id, context) do
    {:ok, user_id} = FlakeId.Ecto.CompatType.dump(user_id)

    ThreadMute
    |> where(user_id: ^user_id)
    |> where(context: ^context)
  end

  def muters_query(context) do
    ThreadMute
    |> join(:inner, [tm], u in assoc(tm, :user))
    |> where([tm], tm.context == ^context)
    |> select([tm, u], u.ap_id)
  end

  def muter_ap_ids(context, ap_ids \\ nil)

  def muter_ap_ids(context, ap_ids) when context not in [nil, ""] do
    context
    |> muters_query()
    |> maybe_filter_on_ap_id(ap_ids)
    |> Repo.all()
  end

  def muter_ap_ids(_context, _ap_ids), do: []

  defp maybe_filter_on_ap_id(query, ap_ids) when is_list(ap_ids) do
    where(query, [tm, u], u.ap_id in ^ap_ids)
  end

  defp maybe_filter_on_ap_id(query, _ap_ids), do: query

  def add_mute(user_id, context) do
    %ThreadMute{}
    |> changeset(%{user_id: user_id, context: context})
    |> Repo.insert()
  end

  def remove_mute(user_id, context) do
    query(user_id, context)
    |> Repo.delete_all()
  end

  def check_muted(user_id, context) do
    query(user_id, context)
    |> Repo.all()
  end
end
