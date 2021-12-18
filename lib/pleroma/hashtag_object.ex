defmodule Pleroma.HashtagObject do
  @moduledoc """
  Through table relationship between hashtags and objects.
  https://hexdocs.pm/ecto/polymorphic-associations-with-many-to-many.html
  """
  use Ecto.Schema

  alias Pleroma.Hashtag
  alias Pleroma.Object

  @primary_key false

  schema "hashtags_objects" do
    belongs_to(:hashtag, Hashtag)
    belongs_to(:object, Object, type: FlakeId.Ecto.CompatType)
  end
end
