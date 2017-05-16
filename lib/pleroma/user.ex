defmodule Pleroma.User do
  use Ecto.Schema

  import Ecto.{Changeset, Query}
  alias Pleroma.{Repo, User, Object, Web}
  alias Comeonin.Pbkdf2
  alias Pleroma.Web.{OStatus, Websub}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Utils

  schema "users" do
    field :bio, :string
    field :email, :string
    field :name, :string
    field :nickname, :string
    field :password_hash, :string
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true
    field :following, {:array, :string}, default: []
    field :ap_id, :string
    field :avatar, :map
    field :local, :boolean, default: true
    field :info, :map, default: %{}

    timestamps()
  end

  def avatar_url(user) do
    case user.avatar do
      %{"url" => [%{"href" => href} | _]} -> href
      _ -> "https://placehold.it/48x48"
    end
  end

  def ap_id(%User{nickname: nickname}) do
    "#{Web.base_url}/users/#{nickname}"
  end

  def ap_followers(%User{} = user) do
    "#{ap_id(user)}/followers"
  end

  def follow_changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:following])
    |> validate_required([:following])
  end

  def user_info(%User{} = user) do
    note_count_query = from a in Object,
      where: fragment("? @> ?", a.data, ^%{actor: user.ap_id, type: "Note"}),
      select: count(a.id)

    follower_count_query = from u in User,
      where: fragment("? @> ?", u.following, ^User.ap_followers(user)),
      select: count(u.id)

    %{
      following_count: length(user.following),
      note_count: Repo.one(note_count_query),
      follower_count: Repo.one(follower_count_query)
    }
  end

  @email_regex ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/
  def remote_user_creation(params) do
    %User{}
    |> cast(params, [:bio, :name, :ap_id, :nickname, :info, :avatar])
    |> validate_required([:name, :ap_id, :nickname])
    |> unique_constraint(:nickname)
    |> validate_format(:nickname, @email_regex)
    |> validate_length(:bio, max: 1000)
    |> validate_length(:name, max: 100)
    |> put_change(:local, false)
  end

  def register_changeset(struct, params \\ %{}) do
    changeset = struct
    |> cast(params, [:bio, :email, :name, :nickname, :password, :password_confirmation])
    |> validate_required([:bio, :email, :name, :nickname, :password, :password_confirmation])
    |> validate_confirmation(:password)
    |> unique_constraint(:email)
    |> unique_constraint(:nickname)
    |> validate_format(:nickname, ~r/^[a-zA-Z\d]+$/)
    |> validate_format(:email, @email_regex)
    |> validate_length(:bio, max: 1000)
    |> validate_length(:name, max: 100)

    if changeset.valid? do
      hashed = Pbkdf2.hashpwsalt(changeset.changes[:password])
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
    if following?(follower, followed) do
      {:error,
       "Could not follow user: #{followed.nickname} is already on your list."}
    else
      if !followed.local && follower.local do
        Websub.subscribe(follower, followed)
      end

      following = [ap_followers | follower.following]
      |> Enum.uniq

      follower
      |> follow_changeset(%{following: following})
      |> Repo.update
    end
  end

  def unfollow(%User{} = follower, %User{} = followed) do
    ap_followers = User.ap_followers(followed)
    if following?(follower, followed) do
      following = follower.following
      |> List.delete(ap_followers)

      { :ok, follower } = follower
      |> follow_changeset(%{following: following})
      |> Repo.update
      { :ok, follower, Utils.fetch_latest_follow(follower, followed)}
    else
      {:error, "Not subscribed!"}
    end
  end

  def following?(%User{} = follower, %User{} = followed) do
    Enum.member?(follower.following, User.ap_followers(followed))
  end

  def get_by_ap_id(ap_id) do
    Repo.get_by(User, ap_id: ap_id)
  end

  def get_cached_by_ap_id(ap_id) do
    key = "ap_id:#{ap_id}"
    Cachex.get!(:user_cache, key, fallback: fn(_) -> get_by_ap_id(ap_id) end)
  end

  def get_cached_by_nickname(nickname) do
    key = "nickname:#{nickname}"
    Cachex.get!(:user_cache, key, fallback: fn(_) -> get_or_fetch_by_nickname(nickname) end)
  end

  def get_by_nickname(nickname) do
    Repo.get_by(User, nickname: nickname)
  end

  def get_cached_user_info(user) do
    key = "user_info:#{user.id}"
    Cachex.get!(:user_cache, key, fallback: fn(_) -> user_info(user) end)
  end

  def get_or_fetch_by_nickname(nickname) do
    with %User{} = user <- get_by_nickname(nickname)  do
      user
    else _e ->
      with [nick, domain] <- String.split(nickname, "@"),
           {:ok, user} <- OStatus.make_user(nickname) do
        user
      else _e -> nil
      end
    end
  end
end
