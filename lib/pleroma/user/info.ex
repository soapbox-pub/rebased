defmodule Pleroma.User.Info do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :banner, :map, default: %{}
    field :source_data, :map, default: %{}
    field :note_count, :integer, default: 0
    field :follower_count, :integer, default: 0
    field :locked, :boolean, default: false
    field :default_scope, :string, default: "public"
    field :blocks, {:array, :string}, default: []
    field :domain_blocks, {:array, :string}, default: []
    field :deactivated, :boolean, default: false
    field :no_rich_text, :boolean, default: false
    field :ap_enabled, :boolean, default: false
    field :keys, :map, default: %{}
  end

  def set_activation_status(info, deactivated) do
    params = %{deactivated: deactivated}

    info
    |> cast(params, [:deactivated])
    |> validate_required([:deactivated])
  end
end
