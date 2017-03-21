defmodule Pleroma.User do
  use Ecto.Schema
  alias Pleroma.User

  schema "users" do
    field :bio, :string
    field :email, :string
    field :name, :string
    field :nickname, :string
    field :password_hash, :string
    field :following, { :array, :string }, default: []
    field :ap_id, :string

    timestamps()
  end

  def ap_id(%User{nickname: nickname}) do
    host =
      Application.get_env(:pleroma, Pleroma.Web.Endpoint)
      |> Keyword.fetch!(:url)
      |> Keyword.fetch!(:host)

    "https://#{host}/users/#{nickname}"
  end

  def ap_followers(%User{} = user) do
    "#{ap_id(user)}/followers"
  end
end
