# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Object
  alias Pleroma.Web
  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Comeonin.Pbkdf2
  alias Pleroma.Formatter
  alias Pleroma.Web.CommonAPI.Utils, as: CommonUtils
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.Websub
  alias Pleroma.Web.OAuth
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.ActivityPub.ActivityPub

  require Logger

  @type t :: %__MODULE__{}

  @primary_key {:id, Pleroma.FlakeId, autogenerate: true}

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
    field(:tags, {:array, :string}, default: [])
    field(:bookmarks, {:array, :string}, default: [])
    field(:last_refreshed_at, :naive_datetime)
    has_many(:notifications, Notification)
    embeds_one(:info, Pleroma.User.Info)

    timestamps()
  end

  def auth_active?(%User{local: false}), do: true

  def auth_active?(%User{info: %User.Info{confirmation_pending: false}}), do: true

  def auth_active?(%User{info: %User.Info{confirmation_pending: true}}),
    do: !Pleroma.Config.get([:instance, :account_activation_required])

  def auth_active?(_), do: false

  def visible_for?(user, for_user \\ nil)

  def visible_for?(%User{id: user_id}, %User{id: for_id}) when user_id == for_id, do: true

  def visible_for?(%User{} = user, for_user) do
    auth_active?(user) || superuser?(for_user)
  end

  def visible_for?(_, _), do: false

  def superuser?(%User{local: true, info: %User.Info{is_admin: true}}), do: true
  def superuser?(%User{local: true, info: %User.Info{is_moderator: true}}), do: true
  def superuser?(_), do: false

  def avatar_url(user) do
    case user.avatar do
      %{"url" => [%{"href" => href} | _]} -> href
      _ -> "#{Web.base_url()}/images/avi.png"
    end
  end

  def banner_url(user) do
    case user.info.banner do
      %{"url" => [%{"href" => href} | _]} -> href
      _ -> "#{Web.base_url()}/images/banner.png"
    end
  end

  def profile_url(%User{info: %{source_data: %{"url" => url}}}), do: url
  def profile_url(%User{ap_id: ap_id}), do: ap_id
  def profile_url(_), do: nil

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
    confirmation_status =
      if opts[:confirmed] || !Pleroma.Config.get([:instance, :account_activation_required]) do
        :confirmed
      else
        :unconfirmed
      end

    info_change = User.Info.confirmation_changeset(%User.Info{}, confirmation_status)

    changeset =
      struct
      |> cast(params, [:bio, :email, :name, :nickname, :password, :password_confirmation])
      |> validate_required([:email, :name, :nickname, :password, :password_confirmation])
      |> validate_confirmation(:password)
      |> unique_constraint(:email)
      |> unique_constraint(:nickname)
      |> validate_exclusion(:nickname, Pleroma.Config.get([Pleroma.User, :restricted_nicknames]))
      |> validate_format(:nickname, local_nickname_regex())
      |> validate_format(:email, @email_regex)
      |> validate_length(:bio, max: 1000)
      |> validate_length(:name, min: 1, max: 100)
      |> put_change(:info, info_change)

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

  defp autofollow_users(user) do
    candidates = Pleroma.Config.get([:instance, :autofollowed_nicknames])

    autofollowed_users =
      from(u in User,
        where: u.local == true,
        where: u.nickname in ^candidates
      )
      |> Repo.all()

    follow_all(user, autofollowed_users)
  end

  @doc "Inserts provided changeset, performs post-registration actions (confirmation email sending etc.)"
  def register(%Ecto.Changeset{} = changeset) do
    with {:ok, user} <- Repo.insert(changeset),
         {:ok, _} <- try_send_confirmation_email(user),
         {:ok, user} <- autofollow_users(user) do
      {:ok, user}
    end
  end

  def try_send_confirmation_email(%User{} = user) do
    if user.info.confirmation_pending &&
         Pleroma.Config.get([:instance, :account_activation_required]) do
      user
      |> Pleroma.UserEmail.account_confirmation_email()
      |> Pleroma.Mailer.deliver()
    else
      {:ok, :noop}
    end
  end

  def needs_update?(%User{local: true}), do: false

  def needs_update?(%User{local: false, last_refreshed_at: nil}), do: true

  def needs_update?(%User{local: false} = user) do
    NaiveDateTime.diff(NaiveDateTime.utc_now(), user.last_refreshed_at) >= 86400
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

  @doc "A mass follow for local users. Ignores blocks and has no side effects"
  @spec follow_all(User.t(), list(User.t())) :: {atom(), User.t()}
  def follow_all(follower, followeds) do
    followed_addresses = Enum.map(followeds, fn %{follower_address: fa} -> fa end)

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
        ]
      )

    {1, [follower]} = Repo.update_all(q, [], returning: true)

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
            update: [push: [following: ^ap_followers]]
          )

        {1, [follower]} = Repo.update_all(q, [], returning: true)

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
          update: [pull: [following: ^ap_followers]]
        )

      {1, [follower]} = Repo.update_all(q, [], returning: true)

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
        with %User{} = followed <- get_or_fetch(followed_identifier),
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

  # This is mostly an SPC migration fix. This guesses the user nickname (by taking the last part of the ap_id and the domain) and tries to get that user
  def get_by_guessed_nickname(ap_id) do
    domain = URI.parse(ap_id).host
    name = List.last(String.split(ap_id, "/"))
    nickname = "#{name}@#{domain}"

    get_by_nickname(nickname)
  end

  def set_cache(user) do
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
    Cachex.fetch!(:user_cache, key, fn _ -> get_or_fetch_by_nickname(nickname) end)
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

  def get_followers_query(%User{id: id, follower_address: follower_address}, nil) do
    from(
      u in User,
      where: fragment("? <@ ?", ^[follower_address], u.following),
      where: u.id != ^id
    )
  end

  def get_followers_query(user, page) do
    from(
      u in get_followers_query(user, nil),
      limit: 20,
      offset: ^((page - 1) * 20)
    )
  end

  def get_followers_query(user), do: get_followers_query(user, nil)

  def get_followers(user, page \\ nil) do
    q = get_followers_query(user, page)

    {:ok, Repo.all(q)}
  end

  def get_followers_ids(user, page \\ nil) do
    q = get_followers_query(user, page)

    Repo.all(from(u in q, select: u.id))
  end

  def get_friends_query(%User{id: id, following: following}, nil) do
    from(
      u in User,
      where: u.follower_address in ^following,
      where: u.id != ^id
    )
  end

  def get_friends_query(user, page) do
    from(
      u in get_friends_query(user, nil),
      limit: 20,
      offset: ^((page - 1) * 20)
    )
  end

  def get_friends_query(user), do: get_friends_query(user, nil)

  def get_friends(user, page \\ nil) do
    q = get_friends_query(user, page)

    {:ok, Repo.all(q)}
  end

  def get_friends_ids(user, page \\ nil) do
    q = get_friends_query(user, page)

    Repo.all(from(u in q, select: u.id))
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
      |> Enum.filter(fn u -> !is_nil(u) end)
      |> Enum.filter(fn u -> !following?(u, user) end)

    {:ok, users}
  end

  def increase_note_count(%User{} = user) do
    info_cng = User.Info.add_to_note_count(user.info, 1)

    cng =
      change(user)
      |> put_embed(:info, info_cng)

    update_and_set_cache(cng)
  end

  def decrease_note_count(%User{} = user) do
    info_cng = User.Info.add_to_note_count(user.info, -1)

    cng =
      change(user)
      |> put_embed(:info, info_cng)

    update_and_set_cache(cng)
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
      from(
        u in User,
        where: ^user.follower_address in u.following,
        where: u.id != ^user.id,
        select: count(u.id)
      )

    follower_count = Repo.one(follower_count_query)

    info_cng =
      user.info
      |> User.Info.set_follower_count(follower_count)

    cng =
      change(user)
      |> put_embed(:info, info_cng)

    update_and_set_cache(cng)
  end

  def get_users_from_set_query(ap_ids, false) do
    from(
      u in User,
      where: u.ap_id in ^ap_ids
    )
  end

  def get_users_from_set_query(ap_ids, true) do
    query = get_users_from_set_query(ap_ids, false)

    from(
      u in query,
      where: u.local == true
    )
  end

  def get_users_from_set(ap_ids, local_only \\ true) do
    get_users_from_set_query(ap_ids, local_only)
    |> Repo.all()
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

  def search(query, resolve \\ false, for_user \\ nil) do
    # Strip the beginning @ off if there is a query
    query = String.trim_leading(query, "@")

    if resolve, do: User.get_or_fetch_by_nickname(query)

    fts_results = do_search(fts_search_subquery(query), for_user)

    {:ok, trigram_results} =
      Repo.transaction(fn ->
        Ecto.Adapters.SQL.query(Repo, "select set_limit(0.25)", [])
        do_search(trigram_search_subquery(query), for_user)
      end)

    Enum.uniq_by(fts_results ++ trigram_results, & &1.id)
  end

  defp do_search(subquery, for_user, options \\ []) do
    q =
      from(
        s in subquery(subquery),
        order_by: [desc: s.search_rank],
        limit: ^(options[:limit] || 20)
      )

    results =
      q
      |> Repo.all()
      |> Enum.filter(&(&1.search_rank > 0))

    boost_search_results(results, for_user)
  end

  defp fts_search_subquery(query) do
    processed_query =
      query
      |> String.replace(~r/\W+/, " ")
      |> String.trim()
      |> String.split()
      |> Enum.map(&(&1 <> ":*"))
      |> Enum.join(" | ")

    from(
      u in User,
      select_merge: %{
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

  defp trigram_search_subquery(query) do
    from(
      u in User,
      select_merge: %{
        search_rank:
          fragment(
            "similarity(?, trim(? || ' ' || coalesce(?, '')))",
            ^query,
            u.nickname,
            u.name
          )
      },
      where: fragment("trim(? || ' ' || coalesce(?, '')) % ?", u.nickname, u.name, ^query)
    )
  end

  defp boost_search_results(results, nil), do: results

  defp boost_search_results(results, for_user) do
    friends_ids = get_friends_ids(for_user)
    followers_ids = get_followers_ids(for_user)

    Enum.map(
      results,
      fn u ->
        search_rank_coef =
          cond do
            u.id in friends_ids ->
              1.2

            u.id in followers_ids ->
              1.1

            true ->
              1
          end

        Map.put(u, :search_rank, u.search_rank * search_rank_coef)
      end
    )
    |> Enum.sort_by(&(-&1.search_rank))
  end

  def blocks_import(%User{} = blocker, blocked_identifiers) when is_list(blocked_identifiers) do
    Enum.map(
      blocked_identifiers,
      fn blocked_identifier ->
        with %User{} = blocked <- get_or_fetch(blocked_identifier),
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
    block(blocker, User.get_by_ap_id(ap_id))
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

  def blocks?(user, %{ap_id: ap_id}) do
    blocks = user.info.blocks
    domain_blocks = user.info.domain_blocks
    %{host: host} = URI.parse(ap_id)

    Enum.member?(blocks, ap_id) ||
      Enum.any?(domain_blocks, fn domain ->
        host == domain
      end)
  end

  def blocked_users(user),
    do: Repo.all(from(u in User, where: u.ap_id in ^user.info.blocks))

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

  def local_user_query do
    from(
      u in User,
      where: u.local == true,
      where: not is_nil(u.nickname)
    )
  end

  def active_local_user_query do
    from(
      u in local_user_query(),
      where: fragment("not (?->'deactivated' @> 'true')", u.info)
    )
  end

  def moderator_user_query do
    from(
      u in User,
      where: u.local == true,
      where: fragment("?->'is_moderator' @> 'true'", u.info)
    )
  end

  def deactivate(%User{} = user, status \\ true) do
    info_cng = User.Info.set_activation_status(user.info, status)

    cng =
      change(user)
      |> put_embed(:info, info_cng)

    update_and_set_cache(cng)
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

    {:ok, user}
  end

  def html_filter_policy(%User{info: %{no_rich_text: true}}) do
    Pleroma.HTML.Scrubber.TwitterText
  end

  @default_scrubbers Pleroma.Config.get([:markup, :scrub_policy])

  def html_filter_policy(_), do: @default_scrubbers

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

  def ap_enabled?(%User{local: true}), do: true
  def ap_enabled?(%User{info: info}), do: info.ap_enabled
  def ap_enabled?(_), do: false

  @doc "Gets or fetch a user by uri or nickname."
  @spec get_or_fetch(String.t()) :: User.t()
  def get_or_fetch("http" <> _host = uri), do: get_or_fetch_by_ap_id(uri)
  def get_or_fetch(nickname), do: get_or_fetch_by_nickname(nickname)

  # wait a period of time and return newest version of the User structs
  # this is because we have synchronous follow APIs and need to simulate them
  # with an async handshake
  def wait_and_refresh(_, %User{local: true} = a, %User{local: true} = b) do
    with %User{} = a <- Repo.get(User, a.id),
         %User{} = b <- Repo.get(User, b.id) do
      {:ok, a, b}
    else
      _e ->
        :error
    end
  end

  def wait_and_refresh(timeout, %User{} = a, %User{} = b) do
    with :ok <- :timer.sleep(timeout),
         %User{} = a <- Repo.get(User, a.id),
         %User{} = b <- Repo.get(User, b.id) do
      {:ok, a, b}
    else
      _e ->
        :error
    end
  end

  def parse_bio(bio, user \\ %User{info: %{source_data: %{}}})
  def parse_bio(nil, _user), do: ""
  def parse_bio(bio, _user) when bio == "", do: bio

  def parse_bio(bio, user) do
    mentions = Formatter.parse_mentions(bio)
    tags = Formatter.parse_tags(bio)

    emoji =
      (user.info.source_data["tag"] || [])
      |> Enum.filter(fn %{"type" => t} -> t == "Emoji" end)
      |> Enum.map(fn %{"icon" => %{"url" => url}, "name" => name} ->
        {String.trim(name, ":"), url}
      end)

    bio
    |> CommonUtils.format_input(mentions, tags, "text/plain", user_links: [format: :full])
    |> Formatter.emojify(emoji)
  end

  def tag(user_identifiers, tags) when is_list(user_identifiers) do
    Repo.transaction(fn ->
      for user_identifier <- user_identifiers, do: tag(user_identifier, tags)
    end)
  end

  def tag(nickname, tags) when is_binary(nickname),
    do: tag(User.get_by_nickname(nickname), tags)

  def tag(%User{} = user, tags),
    do: update_tags(user, Enum.uniq((user.tags || []) ++ normalize_tags(tags)))

  def untag(user_identifiers, tags) when is_list(user_identifiers) do
    Repo.transaction(fn ->
      for user_identifier <- user_identifiers, do: untag(user_identifier, tags)
    end)
  end

  def untag(nickname, tags) when is_binary(nickname),
    do: untag(User.get_by_nickname(nickname), tags)

  def untag(%User{} = user, tags),
    do: update_tags(user, (user.tags || []) -- normalize_tags(tags))

  defp update_tags(%User{} = user, new_tags) do
    {:ok, updated_user} =
      user
      |> change(%{tags: new_tags})
      |> Repo.update()

    updated_user
  end

  def bookmark(%User{} = user, status_id) do
    bookmarks = Enum.uniq(user.bookmarks ++ [status_id])
    update_bookmarks(user, bookmarks)
  end

  def unbookmark(%User{} = user, status_id) do
    bookmarks = Enum.uniq(user.bookmarks -- [status_id])
    update_bookmarks(user, bookmarks)
  end

  def update_bookmarks(%User{} = user, bookmarks) do
    user
    |> change(%{bookmarks: bookmarks})
    |> update_and_set_cache
  end

  defp normalize_tags(tags) do
    [tags]
    |> List.flatten()
    |> Enum.map(&String.downcase(&1))
  end

  defp local_nickname_regex() do
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
end
