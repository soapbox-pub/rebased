defmodule Pleroma.Web.ActivityPub.ObjectValidators.LikeValidator do
  use Ecto.Schema
  import Ecto.Changeset

  alias Pleroma.Web.ActivityPub.ObjectValidators.Types
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.User
  alias Pleroma.Object

  @primary_key false

  embedded_schema do
    field(:id, :string, primary_key: true)
    field(:type, :string)
    field(:object, Types.ObjectID)
    field(:actor, Types.ObjectID)
    field(:context, :string)
    field(:to, {:array, :string})
    field(:cc, {:array, :string})
  end

  def cast_and_validate(data) do
    data
    |> cast_data()
    |> validate_data()
  end

  def cast_data(data) do
    %__MODULE__{}
    |> cast(data, [:id, :type, :object, :actor, :context, :to, :cc])
  end

  def validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["Like"])
    |> validate_required([:id, :type, :object, :actor, :context, :to, :cc])
    |> validate_change(:actor, &actor_valid?/2)
    |> validate_change(:object, &object_valid?/2)
    |> validate_existing_like()
  end

  def validate_existing_like(%{changes: %{actor: actor, object: object}} = cng) do
    if Utils.get_existing_like(actor, %{data: %{"id" => object}}) do
      cng
      |> add_error(:actor, "already liked this object")
      |> add_error(:object, "already liked by this actor")
    else
      cng
    end
  end

  def validate_existing_like(cng), do: cng

  def actor_valid?(field_name, actor) do
    if User.get_cached_by_ap_id(actor) do
      []
    else
      [{field_name, "can't find user"}]
    end
  end

  def object_valid?(field_name, object) do
    if Object.get_cached_by_ap_id(object) do
      []
    else
      [{field_name, "can't find object"}]
    end
  end
end
