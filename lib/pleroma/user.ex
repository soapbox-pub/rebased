defmodule Pleroma.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias Pleroma.{Repo, User}

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

  def follow_changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:following])
    |> validate_required([:following])
  end

  def follow(%User{} = follower, %User{} = followed) do
    ap_followers = User.ap_followers(followed)
    following = [ap_followers | follower.following]
    |> Enum.uniq

    follower
    |> follow_changeset(%{following: following})
    |> Repo.update
  end
end
