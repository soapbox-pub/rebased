defmodule Pleroma.User do
  use Ecto.Schema

  import Ecto.{Changeset, Query}
  alias Pleroma.{Repo, User, Object, Web, Activity, Notification}
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
    field :follower_address, :string
    has_many :notifications, Notification

    timestamps()
  end

  def avatar_url(user) do
    case user.avatar do
      %{"url" => [%{"href" => href} | _]} -> href
      _ -> "https://placehold.it/48x48"
    end
  end

  def banner_url(user) do
    case user.info["banner"] do
      %{"url" => [%{"href" => href} | _]} -> href
      _ -> nil
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

  def info_changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:info])
    |> validate_required([:info])
  end

  def user_info(%User{} = user) do
    %{
      following_count: length(user.following),
      note_count: user.info["note_count"] || 0,
      follower_count: user.info["follower_count"] || 0
    }
  end

  @email_regex ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/
  def remote_user_creation(params) do
    changes = %User{}
    |> cast(params, [:bio, :name, :ap_id, :nickname, :info, :avatar])
    |> validate_required([:name, :ap_id, :nickname])
    |> unique_constraint(:nickname)
    |> validate_format(:nickname, @email_regex)
    |> validate_length(:bio, max: 5000)
    |> validate_length(:name, max: 100)
    |> put_change(:local, false)
    if changes.valid? do
      followers = User.ap_followers(%User{nickname: changes.changes[:nickname]})
      changes
      |> put_change(:follower_address, followers)
    else
      changes
    end
  end

  def update_changeset(struct, params \\ %{}) do
    changeset = struct
    |> cast(params, [:bio, :name])
    |> unique_constraint(:nickname)
    |> validate_format(:nickname, ~r/^[a-zA-Z\d]+$/)
    |> validate_length(:bio, min: 1, max: 1000)
    |> validate_length(:name, min: 1, max: 100)
  end

  def password_update_changeset(struct, params) do
    changeset = struct
    |> cast(params, [:password, :password_confirmation])
    |> validate_required([:password, :password_confirmation])
    |> validate_confirmation(:password)

    if changeset.valid? do
      hashed = Pbkdf2.hashpwsalt(changeset.changes[:password])
      changeset
      |> put_change(:password_hash, hashed)
    else
      changeset
    end
  end

  def reset_password(user, data) do
    Repo.update(password_update_changeset(user, data))
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
    |> validate_length(:bio, min: 1, max: 1000)
    |> validate_length(:name, min: 1, max: 100)

    if changeset.valid? do
      hashed = Pbkdf2.hashpwsalt(changeset.changes[:password])
      ap_id = User.ap_id(%User{nickname: changeset.changes[:nickname]})
      followers = User.ap_followers(%User{nickname: changeset.changes[:nickname]})
      changeset
      |> put_change(:password_hash, hashed)
      |> put_change(:ap_id, ap_id)
      |> put_change(:following, [followers])
      |> put_change(:follower_address, followers)
    else
      changeset
    end
  end

  def follow(%User{} = follower, %User{} = followed) do
    ap_followers = followed.follower_address
    if following?(follower, followed) do
      {:error,
       "Could not follow user: #{followed.nickname} is already on your list."}
    else
      if !followed.local && follower.local do
        Websub.subscribe(follower, followed)
      end

      following = [ap_followers | follower.following]
      |> Enum.uniq

      follower = follower
      |> follow_changeset(%{following: following})
      |> Repo.update

      {:ok, followed} = update_follower_count(followed)

      follower
    end
  end

  def unfollow(%User{} = follower, %User{} = followed) do
    ap_followers = followed.follower_address
    if following?(follower, followed) do
      following = follower.following
      |> List.delete(ap_followers)

      { :ok, follower } = follower
      |> follow_changeset(%{following: following})
      |> Repo.update

      {:ok, followed} = update_follower_count(followed)

      {:ok, follower, Utils.fetch_latest_follow(follower, followed)}
    else
      {:error, "Not subscribed!"}
    end
  end

  def following?(%User{} = follower, %User{} = followed) do
    Enum.member?(follower.following, followed.follower_address)
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

  # TODO: these queries could be more efficient if the type in postgresql wasn't map, but array.
  def get_followers(%User{id: id, follower_address: follower_address}) do
    q = from u in User,
      where: fragment("? @> ?", u.following, ^follower_address ),
      where: u.id != ^id

    {:ok, Repo.all(q)}
  end

  def get_friends(%User{id: id, following: following}) do
    q = from u in User,
      where: u.follower_address in ^following,
      where: u.id != ^id

    {:ok, Repo.all(q)}
  end

  def update_note_count(%User{} = user) do
    note_count_query = from a in Object,
      where: fragment("?->>'actor' = ? and ?->>'type' = 'Note'", a.data, ^user.ap_id, a.data),
      select: count(a.id)

    note_count = Repo.one(note_count_query)

    new_info = Map.put(user.info, "note_count", note_count)

    cs = info_changeset(user, %{info: new_info})

    Repo.update(cs)
  end

  def update_follower_count(%User{} = user) do
    follower_count_query = from u in User,
      where: fragment("? @> ?", u.following, ^user.follower_address),
      select: count(u.id)

    follower_count = Repo.one(follower_count_query)

    new_info = Map.put(user.info, "follower_count", follower_count)

    cs = info_changeset(user, %{info: new_info})

    Repo.update(cs)
  end

  def get_notified_from_activity(%Activity{data: %{"to" => to}} = activity) do
    query = from u in User,
      where: u.ap_id in ^to,
      where: u.local == true

    Repo.all(query)
  end

  def search(query, resolve) do
    if resolve do
      User.get_or_fetch_by_nickname(query)
    end
    q = from u in User,
      where: fragment("(to_tsvector('english', ?) || to_tsvector('english', ?)) @@ plainto_tsquery('english', ?)", u.nickname, u.name, ^query),
      limit: 20
    Repo.all(q)
  end
end
