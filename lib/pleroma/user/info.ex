# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.Info do
  use Ecto.Schema
  import Ecto.Changeset

  alias Pleroma.User.Info

  @type t :: %__MODULE__{}

  embedded_schema do
    field(:blocks, {:array, :string}, default: [])
    field(:domain_blocks, {:array, :string}, default: [])
    field(:mutes, {:array, :string}, default: [])
    field(:muted_reblogs, {:array, :string}, default: [])
    field(:muted_notifications, {:array, :string}, default: [])

    # Found in the wild
    # ap_id -> Where is this used?
    # bio -> Where is this used?
    # avatar -> Where is this used?
    # fqn -> Where is this used?
    # host -> Where is this used?
    # subject _> Where is this used?
  end

  def set_mutes(info, mutes) do
    params = %{mutes: mutes}

    info
    |> cast(params, [:mutes])
    |> validate_required([:mutes])
  end

  @spec set_notification_mutes(Changeset.t(), [String.t()], boolean()) :: Changeset.t()
  def set_notification_mutes(changeset, muted_notifications, notifications?) do
    if notifications? do
      put_change(changeset, :muted_notifications, muted_notifications)
      |> validate_required([:muted_notifications])
    else
      changeset
    end
  end

  def set_blocks(info, blocks) do
    params = %{blocks: blocks}

    info
    |> cast(params, [:blocks])
    |> validate_required([:blocks])
  end

  @spec add_to_mutes(Info.t(), String.t(), boolean()) :: Changeset.t()
  def add_to_mutes(info, muted, notifications?) do
    info
    |> set_mutes(Enum.uniq([muted | info.mutes]))
    |> set_notification_mutes(
      Enum.uniq([muted | info.muted_notifications]),
      notifications?
    )
  end

  @spec remove_from_mutes(Info.t(), String.t()) :: Changeset.t()
  def remove_from_mutes(info, muted) do
    info
    |> set_mutes(List.delete(info.mutes, muted))
    |> set_notification_mutes(List.delete(info.muted_notifications, muted), true)
  end

  def add_to_block(info, blocked) do
    set_blocks(info, Enum.uniq([blocked | info.blocks]))
  end

  def remove_from_block(info, blocked) do
    set_blocks(info, List.delete(info.blocks, blocked))
  end

  def set_domain_blocks(info, domain_blocks) do
    params = %{domain_blocks: domain_blocks}

    info
    |> cast(params, [:domain_blocks])
    |> validate_required([:domain_blocks])
  end

  def add_to_domain_block(info, domain_blocked) do
    set_domain_blocks(info, Enum.uniq([domain_blocked | info.domain_blocks]))
  end

  def remove_from_domain_block(info, domain_blocked) do
    set_domain_blocks(info, List.delete(info.domain_blocks, domain_blocked))
  end

  def add_reblog_mute(info, ap_id) do
    params = %{muted_reblogs: info.muted_reblogs ++ [ap_id]}

    cast(info, params, [:muted_reblogs])
  end

  def remove_reblog_mute(info, ap_id) do
    params = %{muted_reblogs: List.delete(info.muted_reblogs, ap_id)}

    cast(info, params, [:muted_reblogs])
  end
end
