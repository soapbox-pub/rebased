defmodule Pleroma.User do
  use Ecto.Schema

  schema "users" do
    field :bio, :string
    field :email, :string
    field :name, :string
    field :nickname, :string
    field :password_hash, :string

    timestamps()
  end
end
