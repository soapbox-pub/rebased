# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Comeonin.Pbkdf2
  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Registration
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI.Utils, as: CommonUtils
  alias Pleroma.Web.OAuth
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.RelMe
  alias Pleroma.Web.Websub

  require Logger

  @type t :: %__MODULE__{}

  @primary_key {:id, Pleroma.FlakeId, autogenerate: true}

  # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
  @email_regex ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/

  @strict_local_nickname_regex ~r/^[a-zA-Z\d]+$/
  @extended_local_nickname_regex ~r/^[a-zA-Z\d_-]+$/

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
    field(:follower_address, :string)
    field(:search_rank, :float, virtual: true)
    field(:search_type, :integer, virtual: true)
    field(:tags, {:array, :string}, default: [])
    field(:last_refreshed_at, :naive_datetime_usec)
    has_many(:notifications, Notification)
    has_many(:registrations, Registration)
    embeds_one(:info, Pleroma.User.Info)

    timestamps()
  end

  def auth_active?(%User{info: %User.Info{confirmation_pending: true}}),
    do: !Pleroma.Config.get([:instance, :account_activation_required])

  def auth_active?(%User{}), do: true

  def visible_for?(user, for_user \\ nil)

  def visible_for?(%User{id: user_id}, %User{id: for_id}) when user_id == for_id, do: true

  def visible_for?(%User{} = user, for_user) do
    auth_active?(user) || superuser?(for_user)
  end

  def visible_for?(_, _), do: false

  def superuser?(%User{local: true, info: %User.Info{is_admin: true}}), do: true
  def superuser?(%User{local: true, info: %User.Info{is_moderator: true}}), do: true
  def superuser?(_), do: false

  def avatar_url(user, options \\ []) do
    case user.avatar do
      %{"url" => [%{"href" => href} | _]} -> href
      _ -> !options[:no_default] && "#{Web.base_url()}/images/avi.png"
    end
  end

  def banner_url(user, options \\ []) do
    case user.info.banner do
      %{"url" => [%{"href" => href} | _]} -> href
      _ -> !options[:no_default] && "#{Web.base_url()}/images/banner.png"
    end
  end

  def profile_url(%User{info: %{source_data: %{"url" => url}}}), do: url
  def profile_url(%User{ap_id: ap_id}), do: ap_id
  def profile_url(_), do: nil

  def ap_id(%User{nickname: nickname}) do
    "#{Web.base_url()}/users/#{nickname}"
  end

  def ap_followers(%User{follower_address: fa}) when is_binary(fa), do: fa
  def ap_followers(%User{} = user), do: "#{ap_id(user)}/followers"

  def user_info(%User{} = user) do
    oneself = if user.local, do: 1, else: 0

    %{
      following_count: length(user.following) - oneself,
      note_count: user.info.note_count,
      follower_count: user.info.follower_count,
      locked: user.info.locked,
      confirmation_pending: user.info.confirmation_pending,
      default_scope: user.info.default_scope
    }
  end

  def remote_user_creation(params) do
    params =
      params
      |> Map.put(:info, params[:info] || %{})

    info_cng = User.Info.remote_user_creation(%User.Info{}, params[:info])

    changes =
      %User{}
      |> cast(params, [:bio, :name, :ap_id, :nickname, :avatar])
      |> validate_required([:name, :ap_id])
      |> unique_constraint(:nickname)
      |> validate_format(:nickname, @email_regex)
      |> validate_length(:bio, max: 5000)
      |> validate_length(:name, max: 100)
      |> put_change(:local, false)
      |> put_embed(:info, info_cng)

    if changes.valid? do
      case info_cng.changes[:source_data] do
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
    |> cast(params, [:bio, :name, :avatar])
    |> unique_constraint(:nickname)
    |> validate_format(:nickname, local_nickname_regex())
    |> validate_length(:bio, max: 5000)
    |> validate_length(:name, min: 1, max: 100)
  end

  def upgrade_changeset(struct, params \\ %{}) do
    params =
      params
      |> Map.put(:last_refreshed_at, NaiveDateTime.utc_now())

    info_cng =
      struct.info
      |> User.Info.user_upgrade(params[:info])

    struct
    |> cast(params, [:bio, :name, :follower_address, :avatar, :last_refreshed_at])
    |> unique_constraint(:nickname)
    |> validate_format(:nickname, local_nickname_regex())
    |> validate_length(:bio, max: 5000)
    |> validate_length(:name, max: 100)
    |> put_embed(:info, info_cng)
  end

  def password_update_changeset(struct, params) do
    changeset =
      struct
      |> cast(params, [:password, :password_confirmation])
      |> validate_required([:password, :password_confirmation])
      |> validate_confirmation(:password)

    OAuth.Token.delete_user_tokens(struct)
    OAuth.Authorization.delete_user_authorizations(struct)

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

  def register_changeset(struct, params \\ %{}, opts \\ []) do
    need_confirmation? =
      if is_nil(opts[:need_confirmation]) do
        Pleroma.Config.get([:instance, :account_activation_required])
      else
        opts[:need_confirmation]
      end

    info_change =
      User.Info.confirmation_changeset(%User.Info{}, need_confirmation: need_confirmation?)

    changeset =
      struct
      |> cast(params, [:bio, :email, :name, :nickname, :password, :password_confirmation])
      |> validate_required([:name, :nickname, :password, :password_confirmation])
      |> validate_confirmation(:password)
      |> unique_constraint(:email)
      |> unique_constraint(:nickname)
      |> validate_exclusion(:nickname, Pleroma.Config.get([Pleroma.User, :restricted_nicknames]))
      |> validate_format(:nickname, local_nickname_regex())
      |> validate_format(:email, @email_regex)
      |> validate_length(:bio, max: 1000)
      |> validate_length(:name, min: 1, max: 100)
      |> put_change(:info, info_change)

    changeset =
      if opts[:external] do
        changeset
      else
        validate_required(changeset, [:email])
      end

    if changeset.valid? do
      hashed = Pbkdf2.hashpwsalt(changeset.changes[:password])
      ap_id = User.ap_id(%User{nickname: changeset.changes[:nickname]})
      followers = User.ap_followers(%User{nickname: changeset.changes[:nickname]})

      changeset
      |> put_change(:password_hash, hashed)
      |> put_change(:ap_id, ap_id)
      |> unique_constraint(:ap_id)
      |> put_change(:following, [followers])
      |> put_change(:follower_address, followers)
    else
      changeset
    end
  end

  defp autofollow_users(user) do
    candidates = Pleroma.Config.get([:instance, :autofollowed_nicknames])

    autofollowed_users =
      User.Query.build(%{nickname: candidates, local: true})
      |> Repo.all()

    follow_all(user, autofollowed_users)
  end

  @doc "Inserts provided changeset, performs post-registration actions (confirmation email sending etc.)"
  def register(%Ecto.Changeset{} = changeset) do
    with {:ok, user} <- Repo.insert(changeset),
         {:ok, user} <- autofollow_users(user),
         {:ok, user} <- set_cache(user),
         {:ok, _} <- Pleroma.User.WelcomeMessage.post_welcome_message_to_user(user),
         {:ok, _} <- try_send_confirmation_email(user) do
      {:ok, user}
    end
  end

  def try_send_confirmation_email(%User{} = user) do
    if user.info.confirmation_pending &&
         Pleroma.Config.get([:instance, :account_activation_required]) do
      user
      |> Pleroma.Emails.UserEmail.account_confirmation_email()
      |> Pleroma.Emails.Mailer.deliver_async()

      {:ok, :enqueued}
    else
      {:ok, :noop}
    end
  end

  def needs_update?(%User{local: true}), do: false

  def needs_update?(%User{local: false, last_refreshed_at: nil}), do: true

  def needs_update?(%User{local: false} = user) do
    NaiveDateTime.diff(NaiveDateTime.utc_now(), user.last_refreshed_at) >= 86_400
  end

  def needs_update?(_), do: true

  def maybe_direct_follow(%User{} = follower, %User{local: true, info: %{locked: true}}) do
    {:ok, follower}
  end

  def maybe_direct_follow(%User{} = follower, %User{local: true} = followed) do
    follow(follower, followed)
  end

  def maybe_direct_follow(%User{} = follower, %User{} = followed) do
    if not User.ap_enabled?(followed) do
      follow(follower, followed)
    else
      {:ok, follower}
    end
  end

  def maybe_follow(%User{} = follower, %User{info: _info} = followed) do
    if not following?(follower, followed) do
      follow(follower, followed)
    else
      {:ok, follower}
    end
  end

  @doc "A mass follow for local users. Respects blocks in both directions but does not create activities."
  @spec follow_all(User.t(), list(User.t())) :: {atom(), User.t()}
  def follow_all(follower, followeds) do
    followed_addresses =
      followeds
      |> Enum.reject(fn followed -> blocks?(follower, followed) || blocks?(followed, follower) end)
      |> Enum.map(fn %{follower_address: fa} -> fa end)

    q =
      from(u in User,
        where: u.id == ^follower.id,
        update: [
          set: [
            following:
              fragment(
                "array(select distinct unnest (array_cat(?, ?)))",
                u.following,
                ^followed_addresses
              )
          ]
        ],
        select: u
      )

    {1, [follower]} = Repo.update_all(q, [])

    Enum.each(followeds, fn followed ->
      update_follower_count(followed)
    end)

    set_cache(follower)
  end

  def follow(%User{} = follower, %User{info: info} = followed) do
    user_config = Application.get_env(:pleroma, :user)
    deny_follow_blocked = Keyword.get(user_config, :deny_follow_blocked)

    ap_followers = followed.follower_address

    cond do
      following?(follower, followed) or info.deactivated ->
        {:error, "Could not follow user: #{followed.nickname} is already on your list."}

      deny_follow_blocked and blocks?(followed, follower) ->
        {:error, "Could not follow user: #{followed.nickname} blocked you."}

      true ->
        if !followed.local && follower.local && !ap_enabled?(followed) do
          Websub.subscribe(follower, followed)
        end

        q =
          from(u in User,
            where: u.id == ^follower.id,
            update: [push: [following: ^ap_followers]],
            select: u
          )

        {1, [follower]} = Repo.update_all(q, [])

        {:ok, _} = update_follower_count(followed)

        set_cache(follower)
    end
  end

  def unfollow(%User{} = follower, %User{} = followed) do
    ap_followers = followed.follower_address

    if following?(follower, followed) and follower.ap_id != followed.ap_id do
      q =
        from(u in User,
          where: u.id == ^follower.id,
          update: [pull: [following: ^ap_followers]],
          select: u
        )

      {1, [follower]} = Repo.update_all(q, [])

      {:ok, followed} = update_follower_count(followed)

      set_cache(follower)

      {:ok, follower, Utils.fetch_latest_follow(follower, followed)}
    else
      {:error, "Not subscribed!"}
    end
  end

  @spec following?(User.t(), User.t()) :: boolean
  def following?(%User{} = follower, %User{} = followed) do
    Enum.member?(follower.following, followed.follower_address)
  end

  def follow_import(%User{} = follower, followed_identifiers)
      when is_list(followed_identifiers) do
    Enum.map(
      followed_identifiers,
      fn followed_identifier ->
        with {:ok, %User{} = followed} <- get_or_fetch(followed_identifier),
             {:ok, follower} <- maybe_direct_follow(follower, followed),
             {:ok, _} <- ActivityPub.follow(follower, followed) do
          followed
        else
          err ->
            Logger.debug("follow_import failed for #{followed_identifier} with: #{inspect(err)}")
            err
        end
      end
    )
  end

  def locked?(%User{} = user) do
    user.info.locked || false
  end

  def get_by_id(id) do
    Repo.get_by(User, id: id)
  end

  def get_by_ap_id(ap_id) do
    Repo.get_by(User, ap_id: ap_id)
  end

  # This is mostly an SPC migration fix. This guesses the user nickname by taking the last part
  # of the ap_id and the domain and tries to get that user
  def get_by_guessed_nickname(ap_id) do
    domain = URI.parse(ap_id).host
    name = List.last(String.split(ap_id, "/"))
    nickname = "#{name}@#{domain}"

    get_cached_by_nickname(nickname)
  end

  def set_cache({:ok, user}), do: set_cache(user)
  def set_cache({:error, err}), do: {:error, err}

  def set_cache(%User{} = user) do
    Cachex.put(:user_cache, "ap_id:#{user.ap_id}", user)
    Cachex.put(:user_cache, "nickname:#{user.nickname}", user)
    Cachex.put(:user_cache, "user_info:#{user.id}", user_info(user))
    {:ok, user}
  end

  def update_and_set_cache(changeset) do
    with {:ok, user} <- Repo.update(changeset) do
      set_cache(user)
    else
      e -> e
    end
  end

  def invalidate_cache(user) do
    Cachex.del(:user_cache, "ap_id:#{user.ap_id}")
    Cachex.del(:user_cache, "nickname:#{user.nickname}")
    Cachex.del(:user_cache, "user_info:#{user.id}")
  end

  def get_cached_by_ap_id(ap_id) do
    key = "ap_id:#{ap_id}"
    Cachex.fetch!(:user_cache, key, fn _ -> get_by_ap_id(ap_id) end)
  end

  def get_cached_by_id(id) do
    key = "id:#{id}"

    ap_id =
      Cachex.fetch!(:user_cache, key, fn _ ->
        user = get_by_id(id)

        if user do
          Cachex.put(:user_cache, "ap_id:#{user.ap_id}", user)
          {:commit, user.ap_id}
        else
          {:ignore, ""}
        end
      end)

    get_cached_by_ap_id(ap_id)
  end

  def get_cached_by_nickname(nickname) do
    key = "nickname:#{nickname}"

    Cachex.fetch!(:user_cache, key, fn ->
      user_result = get_or_fetch_by_nickname(nickname)

      case user_result do
        {:ok, user} -> {:commit, user}
        {:error, _error} -> {:ignore, nil}
      end
    end)
  end

  def get_cached_by_nickname_or_id(nickname_or_id) do
    get_cached_by_id(nickname_or_id) || get_cached_by_nickname(nickname_or_id)
  end

  def get_by_nickname(nickname) do
    Repo.get_by(User, nickname: nickname) ||
      if Regex.match?(~r(@#{Pleroma.Web.Endpoint.host()})i, nickname) do
        Repo.get_by(User, nickname: local_nickname(nickname))
      end
  end

  def get_by_email(email), do: Repo.get_by(User, email: email)

  def get_by_nickname_or_email(nickname_or_email) do
    get_by_nickname(nickname_or_email) || get_by_email(nickname_or_email)
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
      {:ok, user}
    else
      _e ->
        with [_nick, _domain] <- String.split(nickname, "@"),
             {:ok, user} <- fetch_by_nickname(nickname) do
          if Pleroma.Config.get([:fetch_initial_posts, :enabled]) do
            fetch_initial_posts(user)
          end

          {:ok, user}
        else
          _e -> {:error, "not found " <> nickname}
        end
    end
  end

  @doc "Fetch some posts when the user has just been federated with"
  def fetch_initial_posts(user),
    do: PleromaJobQueue.enqueue(:background, __MODULE__, [:fetch_initial_posts, user])

  @spec get_followers_query(User.t(), pos_integer() | nil) :: Ecto.Query.t()
  def get_followers_query(%User{} = user, nil) do
    User.Query.build(%{followers: user})
  end

  def get_followers_query(user, page) do
    from(u in get_followers_query(user, nil))
    |> User.Query.paginate(page, 20)
  end

  @spec get_followers_query(User.t()) :: Ecto.Query.t()
  def get_followers_query(user), do: get_followers_query(user, nil)

  def get_followers(user, page \\ nil) do
    q = get_followers_query(user, page)

    {:ok, Repo.all(q)}
  end

  def get_followers_ids(user, page \\ nil) do
    q = get_followers_query(user, page)

    Repo.all(from(u in q, select: u.id))
  end

  @spec get_friends_query(User.t(), pos_integer() | nil) :: Ecto.Query.t()
  def get_friends_query(%User{} = user, nil) do
    User.Query.build(%{friends: user})
  end

  def get_friends_query(user, page) do
    from(u in get_friends_query(user, nil))
    |> User.Query.paginate(page, 20)
  end

  @spec get_friends_query(User.t()) :: Ecto.Query.t()
  def get_friends_query(user), do: get_friends_query(user, nil)

  def get_friends(user, page \\ nil) do
    q = get_friends_query(user, page)

    {:ok, Repo.all(q)}
  end

  def get_friends_ids(user, page \\ nil) do
    q = get_friends_query(user, page)

    Repo.all(from(u in q, select: u.id))
  end

  @spec get_follow_requests(User.t()) :: {:ok, [User.t()]}
  def get_follow_requests(%User{} = user) do
    users =
      Activity.follow_requests_for_actor(user)
      |> join(:inner, [a], u in User, on: a.actor == u.ap_id)
      |> where([a, u], not fragment("? @> ?", u.following, ^[user.follower_address]))
      |> group_by([a, u], u.id)
      |> select([a, u], u)
      |> Repo.all()

    {:ok, users}
  end

  def increase_note_count(%User{} = user) do
    User
    |> where(id: ^user.id)
    |> update([u],
      set: [
        info:
          fragment(
            "jsonb_set(?, '{note_count}', ((?->>'note_count')::int + 1)::varchar::jsonb, true)",
            u.info,
            u.info
          )
      ]
    )
    |> select([u], u)
    |> Repo.update_all([])
    |> case do
      {1, [user]} -> set_cache(user)
      _ -> {:error, user}
    end
  end

  def decrease_note_count(%User{} = user) do
    User
    |> where(id: ^user.id)
    |> update([u],
      set: [
        info:
          fragment(
            "jsonb_set(?, '{note_count}', (greatest(0, (?->>'note_count')::int - 1))::varchar::jsonb, true)",
            u.info,
            u.info
          )
      ]
    )
    |> select([u], u)
    |> Repo.update_all([])
    |> case do
      {1, [user]} -> set_cache(user)
      _ -> {:error, user}
    end
  end

  def update_note_count(%User{} = user) do
    note_count_query =
      from(
        a in Object,
        where: fragment("?->>'actor' = ? and ?->>'type' = 'Note'", a.data, ^user.ap_id, a.data),
        select: count(a.id)
      )

    note_count = Repo.one(note_count_query)

    info_cng = User.Info.set_note_count(user.info, note_count)

    cng =
      change(user)
      |> put_embed(:info, info_cng)

    update_and_set_cache(cng)
  end

  def update_follower_count(%User{} = user) do
    follower_count_query =
      User.Query.build(%{followers: user}) |> select([u], %{count: count(u.id)})

    User
    |> where(id: ^user.id)
    |> join(:inner, [u], s in subquery(follower_count_query))
    |> update([u, s],
      set: [
        info:
          fragment(
            "jsonb_set(?, '{follower_count}', ?::varchar::jsonb, true)",
            u.info,
            s.count
          )
      ]
    )
    |> select([u], u)
    |> Repo.update_all([])
    |> case do
      {1, [user]} -> set_cache(user)
      _ -> {:error, user}
    end
  end

  @spec get_users_from_set([String.t()], boolean()) :: [User.t()]
  def get_users_from_set(ap_ids, local_only \\ true) do
    criteria = %{ap_id: ap_ids}
    criteria = if local_only, do: Map.put(criteria, :local, true), else: criteria

    User.Query.build(criteria)
    |> Repo.all()
  end

  @spec get_recipients_from_activity(Activity.t()) :: [User.t()]
  def get_recipients_from_activity(%Activity{recipients: to}) do
    User.Query.build(%{recipients_from_activity: to, local: true})
    |> Repo.all()
  end

  def search(query, resolve \\ false, for_user \\ nil) do
    # Strip the beginning @ off if there is a query
    query = String.trim_leading(query, "@")

    if resolve, do: get_or_fetch(query)

    {:ok, results} =
      Repo.transaction(fn ->
        Ecto.Adapters.SQL.query(Repo, "select set_limit(0.25)", [])
        Repo.all(search_query(query, for_user))
      end)

    results
  end

  def search_query(query, for_user) do
    fts_subquery = fts_search_subquery(query)
    trigram_subquery = trigram_search_subquery(query)
    union_query = from(s in trigram_subquery, union_all: ^fts_subquery)
    distinct_query = from(s in subquery(union_query), order_by: s.search_type, distinct: s.id)

    from(s in subquery(boost_search_rank_query(distinct_query, for_user)),
      order_by: [desc: s.search_rank],
      limit: 20
    )
  end

  defp boost_search_rank_query(query, nil), do: query

  defp boost_search_rank_query(query, for_user) do
    friends_ids = get_friends_ids(for_user)
    followers_ids = get_followers_ids(for_user)

    from(u in subquery(query),
      select_merge: %{
        search_rank:
          fragment(
            """
             CASE WHEN (?) THEN (?) * 1.3
             WHEN (?) THEN (?) * 1.2
             WHEN (?) THEN (?) * 1.1
             ELSE (?) END
            """,
            u.id in ^friends_ids and u.id in ^followers_ids,
            u.search_rank,
            u.id in ^friends_ids,
            u.search_rank,
            u.id in ^followers_ids,
            u.search_rank,
            u.search_rank
          )
      }
    )
  end

  defp fts_search_subquery(term, query \\ User) do
    processed_query =
      term
      |> String.replace(~r/\W+/, " ")
      |> String.trim()
      |> String.split()
      |> Enum.map(&(&1 <> ":*"))
      |> Enum.join(" | ")

    from(
      u in query,
      select_merge: %{
        search_type: ^0,
        search_rank:
          fragment(
            """
            ts_rank_cd(
              setweight(to_tsvector('simple', regexp_replace(?, '\\W', ' ', 'g')), 'A') ||
              setweight(to_tsvector('simple', regexp_replace(coalesce(?, ''), '\\W', ' ', 'g')), 'B'),
              to_tsquery('simple', ?),
              32
            )
            """,
            u.nickname,
            u.name,
            ^processed_query
          )
      },
      where:
        fragment(
          """
            (setweight(to_tsvector('simple', regexp_replace(?, '\\W', ' ', 'g')), 'A') ||
            setweight(to_tsvector('simple', regexp_replace(coalesce(?, ''), '\\W', ' ', 'g')), 'B')) @@ to_tsquery('simple', ?)
          """,
          u.nickname,
          u.name,
          ^processed_query
        )
    )
  end

  defp trigram_search_subquery(term) do
    from(
      u in User,
      select_merge: %{
        # ^1 gives 'Postgrex expected a binary, got 1' for some weird reason
        search_type: fragment("?", 1),
        search_rank:
          fragment(
            "similarity(?, trim(? || ' ' || coalesce(?, '')))",
            ^term,
            u.nickname,
            u.name
          )
      },
      where: fragment("trim(? || ' ' || coalesce(?, '')) % ?", u.nickname, u.name, ^term)
    )
  end

  def blocks_import(%User{} = blocker, blocked_identifiers) when is_list(blocked_identifiers) do
    Enum.map(
      blocked_identifiers,
      fn blocked_identifier ->
        with {:ok, %User{} = blocked} <- get_or_fetch(blocked_identifier),
             {:ok, blocker} <- block(blocker, blocked),
             {:ok, _} <- ActivityPub.block(blocker, blocked) do
          blocked
        else
          err ->
            Logger.debug("blocks_import failed for #{blocked_identifier} with: #{inspect(err)}")
            err
        end
      end
    )
  end

  def mute(muter, %User{ap_id: ap_id}) do
    info_cng =
      muter.info
      |> User.Info.add_to_mutes(ap_id)

    cng =
      change(muter)
      |> put_embed(:info, info_cng)

    update_and_set_cache(cng)
  end

  def unmute(muter, %{ap_id: ap_id}) do
    info_cng =
      muter.info
      |> User.Info.remove_from_mutes(ap_id)

    cng =
      change(muter)
      |> put_embed(:info, info_cng)

    update_and_set_cache(cng)
  end

  def subscribe(subscriber, %{ap_id: ap_id}) do
    deny_follow_blocked = Pleroma.Config.get([:user, :deny_follow_blocked])

    with %User{} = subscribed <- get_cached_by_ap_id(ap_id) do
      blocked = blocks?(subscribed, subscriber) and deny_follow_blocked

      if blocked do
        {:error, "Could not subscribe: #{subscribed.nickname} is blocking you"}
      else
        info_cng =
          subscribed.info
          |> User.Info.add_to_subscribers(subscriber.ap_id)

        change(subscribed)
        |> put_embed(:info, info_cng)
        |> update_and_set_cache()
      end
    end
  end

  def unsubscribe(unsubscriber, %{ap_id: ap_id}) do
    with %User{} = user <- get_cached_by_ap_id(ap_id) do
      info_cng =
        user.info
        |> User.Info.remove_from_subscribers(unsubscriber.ap_id)

      change(user)
      |> put_embed(:info, info_cng)
      |> update_and_set_cache()
    end
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

    blocker =
      if subscribed_to?(blocked, blocker) do
        {:ok, blocker} = unsubscribe(blocked, blocker)
        blocker
      else
        blocker
      end

    if following?(blocked, blocker) do
      unfollow(blocked, blocker)
    end

    {:ok, blocker} = update_follower_count(blocker)

    info_cng =
      blocker.info
      |> User.Info.add_to_block(ap_id)

    cng =
      change(blocker)
      |> put_embed(:info, info_cng)

    update_and_set_cache(cng)
  end

  # helper to handle the block given only an actor's AP id
  def block(blocker, %{ap_id: ap_id}) do
    block(blocker, get_cached_by_ap_id(ap_id))
  end

  def unblock(blocker, %{ap_id: ap_id}) do
    info_cng =
      blocker.info
      |> User.Info.remove_from_block(ap_id)

    cng =
      change(blocker)
      |> put_embed(:info, info_cng)

    update_and_set_cache(cng)
  end

  def mutes?(nil, _), do: false
  def mutes?(user, %{ap_id: ap_id}), do: Enum.member?(user.info.mutes, ap_id)

  def blocks?(user, %{ap_id: ap_id}) do
    blocks = user.info.blocks
    domain_blocks = user.info.domain_blocks
    %{host: host} = URI.parse(ap_id)

    Enum.member?(blocks, ap_id) ||
      Enum.any?(domain_blocks, fn domain ->
        host == domain
      end)
  end

  def subscribed_to?(user, %{ap_id: ap_id}) do
    with %User{} = target <- get_cached_by_ap_id(ap_id) do
      Enum.member?(target.info.subscribers, user.ap_id)
    end
  end

  @spec muted_users(User.t()) :: [User.t()]
  def muted_users(user) do
    User.Query.build(%{ap_id: user.info.mutes})
    |> Repo.all()
  end

  @spec blocked_users(User.t()) :: [User.t()]
  def blocked_users(user) do
    User.Query.build(%{ap_id: user.info.blocks})
    |> Repo.all()
  end

  @spec subscribers(User.t()) :: [User.t()]
  def subscribers(user) do
    User.Query.build(%{ap_id: user.info.subscribers})
    |> Repo.all()
  end

  def block_domain(user, domain) do
    info_cng =
      user.info
      |> User.Info.add_to_domain_block(domain)

    cng =
      change(user)
      |> put_embed(:info, info_cng)

    update_and_set_cache(cng)
  end

  def unblock_domain(user, domain) do
    info_cng =
      user.info
      |> User.Info.remove_from_domain_block(domain)

    cng =
      change(user)
      |> put_embed(:info, info_cng)

    update_and_set_cache(cng)
  end

  def deactivate(%User{} = user, status \\ true) do
    info_cng = User.Info.set_activation_status(user.info, status)

    cng =
      change(user)
      |> put_embed(:info, info_cng)

    update_and_set_cache(cng)
  end

  def update_notification_settings(%User{} = user, settings \\ %{}) do
    info_changeset = User.Info.update_notification_settings(user.info, settings)

    change(user)
    |> put_embed(:info, info_changeset)
    |> update_and_set_cache()
  end

  @spec delete(User.t()) :: :ok
  def delete(%User{} = user),
    do: PleromaJobQueue.enqueue(:background, __MODULE__, [:delete, user])

  @spec perform(atom(), User.t()) :: {:ok, User.t()}
  def perform(:delete, %User{} = user) do
    {:ok, user} = User.deactivate(user)

    # Remove all relationships
    {:ok, followers} = User.get_followers(user)

    Enum.each(followers, fn follower -> User.unfollow(follower, user) end)

    {:ok, friends} = User.get_friends(user)

    Enum.each(friends, fn followed -> User.unfollow(user, followed) end)

    delete_user_activities(user)
  end

  @spec perform(atom(), User.t()) :: {:ok, User.t()}
  def perform(:fetch_initial_posts, %User{} = user) do
    pages = Pleroma.Config.get!([:fetch_initial_posts, :pages])

    Enum.each(
      # Insert all the posts in reverse order, so they're in the right order on the timeline
      Enum.reverse(Utils.fetch_ordered_collection(user.info.source_data["outbox"], pages)),
      &Pleroma.Web.Federator.incoming_ap_doc/1
    )

    {:ok, user}
  end

  def delete_user_activities(%User{ap_id: ap_id} = user) do
    stream =
      ap_id
      |> Activity.query_by_actor()
      |> Activity.with_preloaded_object()
      |> Repo.stream()

    Repo.transaction(fn -> Enum.each(stream, &delete_activity(&1)) end, timeout: :infinity)

    {:ok, user}
  end

  defp delete_activity(%{data: %{"type" => "Create"}} = activity) do
    Object.normalize(activity) |> ActivityPub.delete()
  end

  defp delete_activity(_activity), do: "Doing nothing"

  def html_filter_policy(%User{info: %{no_rich_text: true}}) do
    Pleroma.HTML.Scrubber.TwitterText
  end

  @default_scrubbers Pleroma.Config.get([:markup, :scrub_policy])

  def html_filter_policy(_), do: @default_scrubbers

  def fetch_by_ap_id(ap_id) do
    ap_try = ActivityPub.make_user_from_ap_id(ap_id)

    case ap_try do
      {:ok, user} ->
        {:ok, user}

      _ ->
        case OStatus.make_user(ap_id) do
          {:ok, user} -> {:ok, user}
          _ -> {:error, "Could not fetch by AP id"}
        end
    end
  end

  def get_or_fetch_by_ap_id(ap_id) do
    user = get_cached_by_ap_id(ap_id)

    if !is_nil(user) and !User.needs_update?(user) do
      {:ok, user}
    else
      # Whether to fetch initial posts for the user (if it's a new user & the fetching is enabled)
      should_fetch_initial = is_nil(user) and Pleroma.Config.get([:fetch_initial_posts, :enabled])

      resp = fetch_by_ap_id(ap_id)

      if should_fetch_initial do
        with {:ok, %User{} = user} <- resp do
          fetch_initial_posts(user)
        end
      end

      resp
    end
  end

  def get_or_create_instance_user do
    relay_uri = "#{Pleroma.Web.Endpoint.url()}/relay"

    if user = get_cached_by_ap_id(relay_uri) do
      user
    else
      changes =
        %User{info: %User.Info{}}
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
        source_data: %{"publicKey" => %{"publicKeyPem" => public_key_pem}}
      }) do
    key =
      public_key_pem
      |> :public_key.pem_decode()
      |> hd()
      |> :public_key.pem_entry_decode()

    {:ok, key}
  end

  # OStatus Magic Key
  def public_key_from_info(%{magic_key: magic_key}) do
    {:ok, Pleroma.Web.Salmon.decode_key(magic_key)}
  end

  def get_public_key_for_ap_id(ap_id) do
    with {:ok, %User{} = user} <- get_or_fetch_by_ap_id(ap_id),
         {:ok, public_key} <- public_key_from_info(user.info) do
      {:ok, public_key}
    else
      _ -> :error
    end
  end

  defp blank?(""), do: nil
  defp blank?(n), do: n

  def insert_or_update_user(data) do
    data
    |> Map.put(:name, blank?(data[:name]) || data[:nickname])
    |> remote_user_creation()
    |> Repo.insert(on_conflict: :replace_all, conflict_target: :nickname)
    |> set_cache()
  end

  def ap_enabled?(%User{local: true}), do: true
  def ap_enabled?(%User{info: info}), do: info.ap_enabled
  def ap_enabled?(_), do: false

  @doc "Gets or fetch a user by uri or nickname."
  @spec get_or_fetch(String.t()) :: {:ok, User.t()} | {:error, String.t()}
  def get_or_fetch("http" <> _host = uri), do: get_or_fetch_by_ap_id(uri)
  def get_or_fetch(nickname), do: get_or_fetch_by_nickname(nickname)

  # wait a period of time and return newest version of the User structs
  # this is because we have synchronous follow APIs and need to simulate them
  # with an async handshake
  def wait_and_refresh(_, %User{local: true} = a, %User{local: true} = b) do
    with %User{} = a <- User.get_cached_by_id(a.id),
         %User{} = b <- User.get_cached_by_id(b.id) do
      {:ok, a, b}
    else
      _e ->
        :error
    end
  end

  def wait_and_refresh(timeout, %User{} = a, %User{} = b) do
    with :ok <- :timer.sleep(timeout),
         %User{} = a <- User.get_cached_by_id(a.id),
         %User{} = b <- User.get_cached_by_id(b.id) do
      {:ok, a, b}
    else
      _e ->
        :error
    end
  end

  def parse_bio(bio) when is_binary(bio) and bio != "" do
    bio
    |> CommonUtils.format_input("text/plain", mentions_format: :full)
    |> elem(0)
  end

  def parse_bio(_), do: ""

  def parse_bio(bio, user) when is_binary(bio) and bio != "" do
    # TODO: get profile URLs other than user.ap_id
    profile_urls = [user.ap_id]

    bio
    |> CommonUtils.format_input("text/plain",
      mentions_format: :full,
      rel: &RelMe.maybe_put_rel_me(&1, profile_urls)
    )
    |> elem(0)
  end

  def parse_bio(_, _), do: ""

  def tag(user_identifiers, tags) when is_list(user_identifiers) do
    Repo.transaction(fn ->
      for user_identifier <- user_identifiers, do: tag(user_identifier, tags)
    end)
  end

  def tag(nickname, tags) when is_binary(nickname),
    do: tag(get_by_nickname(nickname), tags)

  def tag(%User{} = user, tags),
    do: update_tags(user, Enum.uniq((user.tags || []) ++ normalize_tags(tags)))

  def untag(user_identifiers, tags) when is_list(user_identifiers) do
    Repo.transaction(fn ->
      for user_identifier <- user_identifiers, do: untag(user_identifier, tags)
    end)
  end

  def untag(nickname, tags) when is_binary(nickname),
    do: untag(get_by_nickname(nickname), tags)

  def untag(%User{} = user, tags),
    do: update_tags(user, (user.tags || []) -- normalize_tags(tags))

  defp update_tags(%User{} = user, new_tags) do
    {:ok, updated_user} =
      user
      |> change(%{tags: new_tags})
      |> update_and_set_cache()

    updated_user
  end

  defp normalize_tags(tags) do
    [tags]
    |> List.flatten()
    |> Enum.map(&String.downcase(&1))
  end

  defp local_nickname_regex do
    if Pleroma.Config.get([:instance, :extended_nickname_format]) do
      @extended_local_nickname_regex
    else
      @strict_local_nickname_regex
    end
  end

  def local_nickname(nickname_or_mention) do
    nickname_or_mention
    |> full_nickname()
    |> String.split("@")
    |> hd()
  end

  def full_nickname(nickname_or_mention),
    do: String.trim_leading(nickname_or_mention, "@")

  def error_user(ap_id) do
    %User{
      name: ap_id,
      ap_id: ap_id,
      info: %User.Info{},
      nickname: "erroruser@example.com",
      inserted_at: NaiveDateTime.utc_now()
    }
  end

  @spec all_superusers() :: [User.t()]
  def all_superusers do
    User.Query.build(%{super_users: true, local: true})
    |> Repo.all()
  end

  def showing_reblogs?(%User{} = user, %User{} = target) do
    target.ap_id not in user.info.muted_reblogs
  end
end
