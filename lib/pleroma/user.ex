defmodule Pleroma.User do
  use Ecto.Schema

  import Ecto.{Changeset, Query}
  alias Pleroma.{Repo, User, Object, Web, Activity, Notification}
  alias Comeonin.Pbkdf2
  alias Pleroma.Web.{OStatus, Websub}
  alias Pleroma.Web.ActivityPub.{Utils, ActivityPub}

  schema "users" do
    field(:bio, :string)
    field(:email, :string)
    field(:name, :string)
    field(:nickname, :string)
    field(:password_hash, :string)
    field(:password, :string, virtual: true)
    field(:password_confirmation, :string, virtual: true)
    field(:following, {:array, :string}, default: [])
    field(:ap_id, :string)
    field(:avatar, :map)
    field(:local, :boolean, default: true)
    field(:info, :map, default: %{})
    field(:follower_address, :string)
    field(:search_distance, :float, virtual: true)
    field(:last_refreshed_at, :naive_datetime)
    has_many(:notifications, Notification)

    timestamps()
  end

  def avatar_url(user) do
    case user.avatar do
      %{"url" => [%{"href" => href} | _]} -> href
      _ -> "#{Web.base_url()}/images/avi.png"
    end
  end

  def banner_url(user) do
    case user.info["banner"] do
      %{"url" => [%{"href" => href} | _]} -> href
      _ -> "#{Web.base_url()}/images/banner.png"
    end
  end

  def ap_id(%User{nickname: nickname}) do
    "#{Web.base_url()}/users/#{nickname}"
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
    oneself = if user.local, do: 1, else: 0

    %{
      following_count: length(user.following) - oneself,
      note_count: user.info["note_count"] || 0,
      follower_count: user.info["follower_count"] || 0,
      locked: user.info["locked"] || false,
      default_scope: user.info["default_scope"] || "public"
    }
  end

  @email_regex ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/
  def remote_user_creation(params) do
    changes =
      %User{}
      |> cast(params, [:bio, :name, :ap_id, :nickname, :info, :avatar])
      |> validate_required([:name, :ap_id])
      |> unique_constraint(:nickname)
      |> validate_format(:nickname, @email_regex)
      |> validate_length(:bio, max: 5000)
      |> validate_length(:name, max: 100)
      |> put_change(:local, false)

    if changes.valid? do
      case changes.changes[:info]["source_data"] do
        %{"followers" => followers} ->
          changes
          |> put_change(:follower_address, followers)

        _ ->
          followers = User.ap_followers(%User{nickname: changes.changes[:nickname]})

          changes
          |> put_change(:follower_address, followers)
      end
    else
      changes
    end
  end

  def update_changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:bio, :name])
    |> unique_constraint(:nickname)
    |> validate_format(:nickname, ~r/^[a-zA-Z\d]+$/)
    |> validate_length(:bio, max: 5000)
    |> validate_length(:name, min: 1, max: 100)
  end

  def upgrade_changeset(struct, params \\ %{}) do
    params =
      params
      |> Map.put(:last_refreshed_at, NaiveDateTime.utc_now())

    struct
    |> cast(params, [:bio, :name, :info, :follower_address, :avatar, :last_refreshed_at])
    |> unique_constraint(:nickname)
    |> validate_format(:nickname, ~r/^[a-zA-Z\d]+$/)
    |> validate_length(:bio, max: 5000)
    |> validate_length(:name, max: 100)
  end

  def password_update_changeset(struct, params) do
    changeset =
      struct
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
    update_and_set_cache(password_update_changeset(user, data))
  end

  def register_changeset(struct, params \\ %{}) do
    changeset =
      struct
      |> cast(params, [:bio, :email, :name, :nickname, :password, :password_confirmation])
      |> validate_required([:email, :name, :nickname, :password, :password_confirmation])
      |> validate_confirmation(:password)
      |> unique_constraint(:email)
      |> unique_constraint(:nickname)
      |> validate_format(:nickname, ~r/^[a-zA-Z\d]+$/)
      |> validate_format(:email, @email_regex)
      |> validate_length(:bio, max: 1000)
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

  def needs_update?(%User{local: true}), do: false

  def needs_update?(%User{local: false, last_refreshed_at: nil}), do: true

  def needs_update?(%User{local: false} = user) do
    NaiveDateTime.diff(NaiveDateTime.utc_now(), user.last_refreshed_at) >= 86400
  end

  def needs_update?(_), do: true

  def maybe_direct_follow(%User{} = follower, %User{info: info} = followed) do
    if !User.ap_enabled?(followed) do
      follow(follower, followed)
    else
      {:ok, follower}
    end
  end

  def maybe_follow(%User{} = follower, %User{info: info} = followed) do
    if not following?(follower, followed) do
      follow(follower, followed)
    else
      {:ok, follower}
    end
  end

  def follow(%User{} = follower, %User{info: info} = followed) do
    user_config = Application.get_env(:pleroma, :user)
    deny_follow_blocked = Keyword.get(user_config, :deny_follow_blocked)

    ap_followers = followed.follower_address

    cond do
      following?(follower, followed) or info["deactivated"] ->
        {:error, "Could not follow user: #{followed.nickname} is already on your list."}

      deny_follow_blocked and blocks?(followed, follower) ->
        {:error, "Could not follow user: #{followed.nickname} blocked you."}

      true ->
        if !followed.local && follower.local && !ap_enabled?(followed) do
          Websub.subscribe(follower, followed)
        end

        following =
          [ap_followers | follower.following]
          |> Enum.uniq()

        follower =
          follower
          |> follow_changeset(%{following: following})
          |> update_and_set_cache

        {:ok, _} = update_follower_count(followed)

        follower
    end
  end

  def unfollow(%User{} = follower, %User{} = followed) do
    ap_followers = followed.follower_address

    if following?(follower, followed) and follower.ap_id != followed.ap_id do
      following =
        follower.following
        |> List.delete(ap_followers)

      {:ok, follower} =
        follower
        |> follow_changeset(%{following: following})
        |> update_and_set_cache

      {:ok, followed} = update_follower_count(followed)

      {:ok, follower, Utils.fetch_latest_follow(follower, followed)}
    else
      {:error, "Not subscribed!"}
    end
  end

  def following?(%User{} = follower, %User{} = followed) do
    Enum.member?(follower.following, followed.follower_address)
  end

  def locked?(%User{} = user) do
    user.info["locked"] || false
  end

  def get_by_ap_id(ap_id) do
    Repo.get_by(User, ap_id: ap_id)
  end

  def update_and_set_cache(changeset) do
    with {:ok, user} <- Repo.update(changeset) do
      Cachex.put(:user_cache, "ap_id:#{user.ap_id}", user)
      Cachex.put(:user_cache, "nickname:#{user.nickname}", user)
      Cachex.put(:user_cache, "user_info:#{user.id}", user_info(user))
      {:ok, user}
    else
      e -> e
    end
  end

  def invalidate_cache(user) do
    Cachex.del(:user_cache, "ap_id:#{user.ap_id}")
    Cachex.del(:user_cache, "nickname:#{user.nickname}")
  end

  def get_cached_by_ap_id(ap_id) do
    key = "ap_id:#{ap_id}"
    Cachex.fetch!(:user_cache, key, fn _ -> get_by_ap_id(ap_id) end)
  end

  def get_cached_by_nickname(nickname) do
    key = "nickname:#{nickname}"
    Cachex.fetch!(:user_cache, key, fn _ -> get_or_fetch_by_nickname(nickname) end)
  end

  def get_by_nickname(nickname) do
    Repo.get_by(User, nickname: nickname)
  end

  def get_by_nickname_or_email(nickname_or_email) do
    case user = Repo.get_by(User, nickname: nickname_or_email) do
      %User{} -> user
      nil -> Repo.get_by(User, email: nickname_or_email)
    end
  end

  def get_cached_user_info(user) do
    key = "user_info:#{user.id}"
    Cachex.fetch!(:user_cache, key, fn _ -> user_info(user) end)
  end

  def fetch_by_nickname(nickname) do
    ap_try = ActivityPub.make_user_from_nickname(nickname)

    case ap_try do
      {:ok, user} -> {:ok, user}
      _ -> OStatus.make_user(nickname)
    end
  end

  def get_or_fetch_by_nickname(nickname) do
    with %User{} = user <- get_by_nickname(nickname) do
      user
    else
      _e ->
        with [_nick, _domain] <- String.split(nickname, "@"),
             {:ok, user} <- fetch_by_nickname(nickname) do
          user
        else
          _e -> nil
        end
    end
  end

  def get_followers_query(%User{id: id, follower_address: follower_address}) do
    from(
      u in User,
      where: fragment("? <@ ?", ^[follower_address], u.following),
      where: u.id != ^id
    )
  end

  def get_followers(user) do
    q = get_followers_query(user)

    {:ok, Repo.all(q)}
  end

  def get_friends_query(%User{id: id, following: following}) do
    from(
      u in User,
      where: u.follower_address in ^following,
      where: u.id != ^id
    )
  end

  def get_friends(user) do
    q = get_friends_query(user)

    {:ok, Repo.all(q)}
  end

  def get_follow_requests_query(%User{} = user) do
    from(
      a in Activity,
      where:
        fragment(
          "? ->> 'type' = 'Follow'",
          a.data
        ),
      where:
        fragment(
          "? ->> 'state' = 'pending'",
          a.data
        ),
      where:
        fragment(
          "? @> ?",
          a.data,
          ^%{"object" => user.ap_id}
        )
    )
  end

  def get_follow_requests(%User{} = user) do
    q = get_follow_requests_query(user)
    reqs = Repo.all(q)

    users =
      Enum.map(reqs, fn req -> req.actor end)
      |> Enum.uniq()
      |> Enum.map(fn ap_id -> get_by_ap_id(ap_id) end)
      |> Enum.filter(fn u -> !following?(u, user) end)

    {:ok, users}
  end

  def increase_note_count(%User{} = user) do
    note_count = (user.info["note_count"] || 0) + 1
    new_info = Map.put(user.info, "note_count", note_count)

    cs = info_changeset(user, %{info: new_info})

    update_and_set_cache(cs)
  end

  def decrease_note_count(%User{} = user) do
    note_count = user.info["note_count"] || 0
    note_count = if note_count <= 0, do: 0, else: note_count - 1
    new_info = Map.put(user.info, "note_count", note_count)

    cs = info_changeset(user, %{info: new_info})

    update_and_set_cache(cs)
  end

  def update_note_count(%User{} = user) do
    note_count_query =
      from(
        a in Object,
        where: fragment("?->>'actor' = ? and ?->>'type' = 'Note'", a.data, ^user.ap_id, a.data),
        select: count(a.id)
      )

    note_count = Repo.one(note_count_query)

    new_info = Map.put(user.info, "note_count", note_count)

    cs = info_changeset(user, %{info: new_info})

    update_and_set_cache(cs)
  end

  def update_follower_count(%User{} = user) do
    follower_count_query =
      from(
        u in User,
        where: ^user.follower_address in u.following,
        where: u.id != ^user.id,
        select: count(u.id)
      )

    follower_count = Repo.one(follower_count_query)

    new_info = Map.put(user.info, "follower_count", follower_count)

    cs = info_changeset(user, %{info: new_info})

    update_and_set_cache(cs)
  end

  def get_notified_from_activity_query(to) do
    from(
      u in User,
      where: u.ap_id in ^to,
      where: u.local == true
    )
  end

  def get_notified_from_activity(%Activity{recipients: to, data: %{"type" => "Announce"} = data}) do
    object = Object.normalize(data["object"])
    actor = User.get_cached_by_ap_id(data["actor"])

    # ensure that the actor who published the announced object appears only once
    to =
      if actor.nickname != nil do
        to ++ [object.data["actor"]]
      else
        to
      end
      |> Enum.uniq()

    query = get_notified_from_activity_query(to)

    Repo.all(query)
  end

  def get_notified_from_activity(%Activity{recipients: to}) do
    query = get_notified_from_activity_query(to)

    Repo.all(query)
  end

  def get_recipients_from_activity(%Activity{recipients: to}) do
    query =
      from(
        u in User,
        where: u.ap_id in ^to,
        or_where: fragment("? && ?", u.following, ^to)
      )

    query = from(u in query, where: u.local == true)

    Repo.all(query)
  end

  def search(query, resolve) do
    # strip the beginning @ off if there is a query
    query = String.trim_leading(query, "@")

    if resolve do
      User.get_or_fetch_by_nickname(query)
    end

    inner =
      from(
        u in User,
        select_merge: %{
          search_distance:
            fragment(
              "? <-> (? || ?)",
              ^query,
              u.nickname,
              u.name
            )
        },
        where: not is_nil(u.nickname)
      )

    q =
      from(
        s in subquery(inner),
        order_by: s.search_distance,
        limit: 20
      )

    Repo.all(q)
  end

  def block(blocker, %User{ap_id: ap_id} = blocked) do
    # sever any follow relationships to prevent leaks per activitypub (Pleroma issue #213)
    blocker =
      if following?(blocker, blocked) do
        {:ok, blocker, _} = unfollow(blocker, blocked)
        blocker
      else
        blocker
      end

    if following?(blocked, blocker) do
      unfollow(blocked, blocker)
    end

    blocks = blocker.info["blocks"] || []
    new_blocks = Enum.uniq([ap_id | blocks])
    new_info = Map.put(blocker.info, "blocks", new_blocks)

    cs = User.info_changeset(blocker, %{info: new_info})
    update_and_set_cache(cs)
  end

  # helper to handle the block given only an actor's AP id
  def block(blocker, %{ap_id: ap_id}) do
    block(blocker, User.get_by_ap_id(ap_id))
  end

  def unblock(user, %{ap_id: ap_id}) do
    blocks = user.info["blocks"] || []
    new_blocks = List.delete(blocks, ap_id)
    new_info = Map.put(user.info, "blocks", new_blocks)

    cs = User.info_changeset(user, %{info: new_info})
    update_and_set_cache(cs)
  end

  def blocks?(user, %{ap_id: ap_id}) do
    blocks = user.info["blocks"] || []
    domain_blocks = user.info["domain_blocks"] || []
    %{host: host} = URI.parse(ap_id)

    Enum.member?(blocks, ap_id) ||
      Enum.any?(domain_blocks, fn domain ->
        host == domain
      end)
  end

  def block_domain(user, domain) do
    domain_blocks = user.info["domain_blocks"] || []
    new_blocks = Enum.uniq([domain | domain_blocks])
    new_info = Map.put(user.info, "domain_blocks", new_blocks)

    cs = User.info_changeset(user, %{info: new_info})
    update_and_set_cache(cs)
  end

  def unblock_domain(user, domain) do
    blocks = user.info["domain_blocks"] || []
    new_blocks = List.delete(blocks, domain)
    new_info = Map.put(user.info, "domain_blocks", new_blocks)

    cs = User.info_changeset(user, %{info: new_info})
    update_and_set_cache(cs)
  end

  def local_user_query() do
    from(
      u in User,
      where: u.local == true,
      where: not is_nil(u.nickname)
    )
  end

  def moderator_user_query() do
    from(
      u in User,
      where: u.local == true,
      where: fragment("?->'is_moderator' @> 'true'", u.info)
    )
  end

  def deactivate(%User{} = user) do
    new_info = Map.put(user.info, "deactivated", true)
    cs = User.info_changeset(user, %{info: new_info})
    update_and_set_cache(cs)
  end

  def delete(%User{} = user) do
    {:ok, user} = User.deactivate(user)

    # Remove all relationships
    {:ok, followers} = User.get_followers(user)

    followers
    |> Enum.each(fn follower -> User.unfollow(follower, user) end)

    {:ok, friends} = User.get_friends(user)

    friends
    |> Enum.each(fn followed -> User.unfollow(user, followed) end)

    query = from(a in Activity, where: a.actor == ^user.ap_id)

    Repo.all(query)
    |> Enum.each(fn activity ->
      case activity.data["type"] do
        "Create" ->
          ActivityPub.delete(Object.normalize(activity.data["object"]))

        # TODO: Do something with likes, follows, repeats.
        _ ->
          "Doing nothing"
      end
    end)

    :ok
  end

  def html_filter_policy(%User{info: %{"no_rich_text" => true}}) do
    Pleroma.HTML.Scrubber.TwitterText
  end

  def html_filter_policy(_), do: nil

  def get_or_fetch_by_ap_id(ap_id) do
    user = get_by_ap_id(ap_id)

    if !is_nil(user) and !User.needs_update?(user) do
      user
    else
      ap_try = ActivityPub.make_user_from_ap_id(ap_id)

      case ap_try do
        {:ok, user} ->
          user

        _ ->
          case OStatus.make_user(ap_id) do
            {:ok, user} -> user
            _ -> {:error, "Could not fetch by AP id"}
          end
      end
    end
  end

  def get_or_create_instance_user do
    relay_uri = "#{Pleroma.Web.Endpoint.url()}/relay"

    if user = get_by_ap_id(relay_uri) do
      user
    else
      changes =
        %User{}
        |> cast(%{}, [:ap_id, :nickname, :local])
        |> put_change(:ap_id, relay_uri)
        |> put_change(:nickname, nil)
        |> put_change(:local, true)
        |> put_change(:follower_address, relay_uri <> "/followers")

      {:ok, user} = Repo.insert(changes)
      user
    end
  end

  # AP style
  def public_key_from_info(%{
        "source_data" => %{"publicKey" => %{"publicKeyPem" => public_key_pem}}
      }) do
    key =
      :public_key.pem_decode(public_key_pem)
      |> hd()
      |> :public_key.pem_entry_decode()

    {:ok, key}
  end

  # OStatus Magic Key
  def public_key_from_info(%{"magic_key" => magic_key}) do
    {:ok, Pleroma.Web.Salmon.decode_key(magic_key)}
  end

  def get_public_key_for_ap_id(ap_id) do
    with %User{} = user <- get_or_fetch_by_ap_id(ap_id),
         {:ok, public_key} <- public_key_from_info(user.info) do
      {:ok, public_key}
    else
      _ -> :error
    end
  end

  defp blank?(""), do: nil
  defp blank?(n), do: n

  def insert_or_update_user(data) do
    data =
      data
      |> Map.put(:name, blank?(data[:name]) || data[:nickname])

    cs = User.remote_user_creation(data)
    Repo.insert(cs, on_conflict: :replace_all, conflict_target: :nickname)
  end

  def ap_enabled?(%User{info: info}), do: info["ap_enabled"]
  def ap_enabled?(_), do: false

  def get_or_fetch(uri_or_nickname) do
    if String.starts_with?(uri_or_nickname, "http") do
      get_or_fetch_by_ap_id(uri_or_nickname)
    else
      get_or_fetch_by_nickname(uri_or_nickname)
    end
  end
end
