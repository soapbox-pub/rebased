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
    "#{Pleroma.Web.base_url}/users/#{nickname}"
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

  def unfollow(%User{} = follower, %User{} = followed) do
    ap_followers = User.ap_followers(followed)
    following = follower.following
    |> List.delete(ap_followers)

    follower
    |> follow_changeset(%{following: following})
    |> Repo.update
  end

  def following?(%User{} = follower, %User{} = followed) do
    Enum.member?(follower.following, User.ap_followers(followed))
  end

  def get_cached_by_ap_id(ap_id) do
    ConCache.get_or_store(:users, "ap_id:#{ap_id}", fn() ->
      # Return false so the cache will store it.
      Repo.get_by(User, ap_id: ap_id) || false
    end)
  end

  def get_cached_by_nickname(nickname) do
    ConCache.get_or_store(:users, "nickname:#{nickname}", fn() ->
      Repo.get_by(User, nickname: nickname) || false
    end)
  end
end
