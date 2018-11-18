defmodule Pleroma.User.Info do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:banner, :map, default: %{})
    field(:source_data, :map, default: %{})
    field(:note_count, :integer, default: 0)
    field(:follower_count, :integer, default: 0)
    field(:locked, :boolean, default: false)
    field(:default_scope, :string, default: "public")
    field(:blocks, {:array, :string}, default: [])
    field(:domain_blocks, {:array, :string}, default: [])
    field(:deactivated, :boolean, default: false)
    field(:no_rich_text, :boolean, default: false)
    field(:ap_enabled, :boolean, default: false)
    field(:is_moderator, :boolean, default: false)
    field(:keys, :string, default: nil)
  end

  def set_activation_status(info, deactivated) do
    params = %{deactivated: deactivated}

    info
    |> cast(params, [:deactivated])
    |> validate_required([:deactivated])
  end

  def add_to_note_count(info, number) do
    set_note_count(info, info.note_count + number)
  end

  def set_note_count(info, number) do
    params = %{note_count: Enum.max([0, number])}

    info
    |> cast(params, [:note_count])
    |> validate_required([:note_count])
  end

  def set_follower_count(info, number) do
    params = %{follower_count: Enum.max([0, number])}

    info
    |> cast(params, [:follower_count])
    |> validate_required([:follower_count])
  end

  def set_blocks(info, blocks) do
    params = %{blocks: blocks}

    info
    |> cast(params, [:blocks])
    |> validate_required([:blocks])
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

  def set_keys(info, keys) do
    params = %{keys: keys}

    info
    |> cast(params, [:keys])
    |> validate_required([:keys])
  end

  def remote_user_creation(info, params) do
    info
    |> cast(params, [:source_data])
  end

  # Receives data from user_data_from_user_object
  def user_upgrade(info, params) do
    info
    |> cast(params, [:ap_enabled, :source_data, :banner, :locked])
  end
end
