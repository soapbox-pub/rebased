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
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true
    field :following, { :array, :string }, default: []
    field :ap_id, :string
    field :avatar, :map

    timestamps()
  end

  def avatar_url(user) do
    case user.avatar do
      %{"url" => [%{"href" => href} | _]} -> href
      _ -> "https://placehold.it/48x48"
    end
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

  def register_changeset(struct, params \\ %{}) do
    changeset = struct
    |> cast(params, [:bio, :email, :name, :nickname, :password, :password_confirmation])
    |> validate_required([:bio, :email, :name, :nickname, :password, :password_confirmation])
    |> validate_confirmation(:password)
    |> unique_constraint(:email)
    |> unique_constraint(:nickname)

    if changeset.valid? do
      hashed = Comeonin.Pbkdf2.hashpwsalt(changeset.changes[:password])
      ap_id = User.ap_id(%User{nickname: changeset.changes[:nickname]})
      followers = User.ap_followers(%User{nickname: changeset.changes[:nickname]})
      changeset
      |> put_change(:password_hash, hashed)
      |> put_change(:ap_id, ap_id)
      |> put_change(:following, [followers])
    else
      changeset
    end
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
    key = "ap_id:#{ap_id}"
    Cachex.get!(:user_cache, key, fallback: fn(_) -> Repo.get_by(User, ap_id: ap_id) end)
  end

  def get_cached_by_nickname(nickname) do
    key = "nickname:#{nickname}"
    Cachex.get!(:user_cache, key, fallback: fn(_) -> Repo.get_by(User, nickname: nickname) end)
  end
end
