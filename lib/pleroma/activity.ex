defmodule Pleroma.Activity do
  use Ecto.Schema

  schema "activities" do
    field :data, :map

    timestamps()
  end
end
