defmodule Pleroma.Object do
  use Ecto.Schema

  schema "objects" do
    field :data, :map

    timestamps()
  end
end
