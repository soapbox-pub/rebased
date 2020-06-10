defmodule Pleroma.Web.ActivityPub.ObjectValidators.UrlObjectValidator do
  use Ecto.Schema

  alias Pleroma.Web.ActivityPub.ObjectValidators.Types

  import Ecto.Changeset
  @primary_key false

  embedded_schema do
    field(:type, :string)
    field(:href, Types.Uri)
    field(:mediaType, :string)
  end

  def changeset(struct, data) do
    struct
    |> cast(data, __schema__(:fields))
    |> validate_required([:type, :href, :mediaType])
  end
end
