# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Comeonin.Pbkdf2
  alias Ecto.Multi
  alias Pleroma.Activity
  alias Pleroma.Keys
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Registration
  alias Pleroma.Repo
  alias Pleroma.RepoStreamer
  alias Pleroma.User
  alias Pleroma.Web
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils, as: CommonUtils
  alias Pleroma.Web.OAuth
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.RelMe
  alias Pleroma.Web.Websub

  require Logger

  @type t :: %__MODULE__{}

  @primary_key {:id, FlakeId.Ecto.CompatType, autogenerate: true}

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
    field(:keys, :string)
    field(:following, {:array, :string}, default: [])
    field(:ap_id, :string)
    field(:avatar, :map)
    field(:local, :boolean, default: true)
    field(:follower_address, :string)
    field(:following_address, :string)
    field(:search_rank, :float, virtual: true)
    field(:search_type, :integer, virtual: true)
    field(:tags, {:array, :string}, default: [])
    field(:last_refreshed_at, :naive_datetime_usec)
    field(:last_digest_emailed_at, :naive_datetime)
    has_many(:notifications, Notification)
    has_many(:registrations, Registration)
    embeds_one(:info, User.Info)

    timestamps()
  end

  def auth_active?(%User{info: %User.Info{confirmation_pending: true}}),
    do: !Pleroma.Config.get([:instance, :account_activation_required])

  def auth_active?(%User{info: %User.Info{deactivated: true}}), do: false

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

  @spec ap_following(User.t()) :: Sring.t()
  def ap_following(%User{following_address: fa}) when is_binary(fa), do: fa
  def ap_following(%User{} = user), do: "#{ap_id(user)}/following"

  def user_info(%User{} = user, args \\ %{}) do
    following_count =
      if args[:following_count],
        do: args[:following_count],
        else: user.info.following_count || following_count(user)

    follower_count =
      if args[:follower_count], do: args[:follower_count], else: user.info.follower_count

    %{
      note_count: user.info.note_count,
      locked: user.info.locked,
      confirmation_pending: user.info.confirmation_pending,
      default_scope: user.info.default_scope
    }
    |> Map.put(:following_count, following_count)
    |> Map.put(:follower_count, follower_count)
  end

  def follow_state(%User{} = user, %User{} = target) do
    follow_activity = Utils.fetch_latest_follow(user, target)

    if follow_activity,
      do: follow_activity.data["state"],
      # Ideally this would be nil, but then Cachex does not commit the value
      else: false
  end

  def get_cached_follow_state(user, target) do
    key = "follow_state:#{user.ap_id}|#{target.ap_id}"
    Cachex.fetch!(:user_cache, key, fn _ -> {:commit, follow_state(user, target)} end)
  end

  def set_follow_state_cache(user_ap_id, target_ap_id, state) do
    Cachex.put(
      :user_cache,
      "follow_state:#{user_ap_id}|#{target_ap_id}",
      state
    )
  end

  def set_info_cache(user, args) do
    Cachex.put(:user_cache, "user_info:#{user.id}", user_info(user, args))
  end

  @spec restrict_deactivated(Ecto.Query.t()) :: Ecto.Query.t()
  def restrict_deactivated(query) do
    from(u in query,
      where: not fragment("? \\? 'deactivated' AND ?->'deactivated' @> 'true'", u.info, u.info)
    )
  end

  def following_count(%User{following: []}), do: 0

  def following_count(%User{} = user) do
    user
    |> get_friends_query()
    |> Repo.aggregate(:count, :id)
  end

  def remote_user_creation(params) do
    bio_limit = Pleroma.Config.get([:instance, :user_bio_length], 5000)
    name_limit = Pleroma.Config.get([:instance, :user_name_length], 100)

    params = Map.put(params, :info, params[:info] || %{})
    info_cng = User.Info.remote_user_creation(%User.Info{}, params[:info])

    changes =
      %User{}
      |> cast(params, [:bio, :name, :ap_id, :nickname, :avatar])
      |> validate_required([:name, :ap_id])
      |> unique_constraint(:nickname)
      |> validate_format(:nickname, @email_regex)
      |> validate_length(:bio, max: bio_limit)
      |> validate_length(:name, max: name_limit)
      |> put_change(:local, false)
      |> put_embed(:info, info_cng)

    if changes.valid? do
      case info_cng.changes[:source_data] do
        %{"followers" => followers, "following" => following} ->
          changes
          |> put_change(:follower_address, followers)
          |> put_change(:following_address, following)

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
    bio_limit = Pleroma.Config.get([:instance, :user_bio_length], 5000)
    name_limit = Pleroma.Config.get([:instance, :user_name_length], 100)

    struct
    |> cast(params, [:bio, :name, :avatar, :following])
    |> unique_constraint(:nickname)
    |> validate_format(:nickname, local_nickname_regex())
    |> validate_length(:bio, max: bio_limit)
    |> validate_length(:name, min: 1, max: name_limit)
  end

  def upgrade_changeset(struct, params \\ %{}, remote? \\ false) do
    bio_limit = Pleroma.Config.get([:instance, :user_bio_length], 5000)
    name_limit = Pleroma.Config.get([:instance, :user_name_length], 100)

    params = Map.put(params, :last_refreshed_at, NaiveDateTime.utc_now())
    info_cng = User.Info.user_upgrade(struct.info, params[:info], remote?)

    struct
    |> cast(params, [
      :bio,
      :name,
      :follower_address,
      :following_address,
      :avatar,
      :last_refreshed_at
    ])
    |> unique_constraint(:nickname)
    |> validate_format(:nickname, local_nickname_regex())
    |> validate_length(:bio, max: bio_limit)
    |> validate_length(:name, max: name_limit)
    |> put_embed(:info, info_cng)
  end

  def password_update_changeset(struct, params) do
    struct
    |> cast(params, [:password, :password_confirmation])
    |> validate_required([:password, :password_confirmation])
    |> validate_confirmation(:password)
    |> put_password_hash
  end

  @spec reset_password(User.t(), map) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def reset_password(%User{id: user_id} = user, data) do
    multi =
      Multi.new()
      |> Multi.update(:user, password_update_changeset(user, data))
      |> Multi.delete_all(:tokens, OAuth.Token.Query.get_by_user(user_id))
      |> Multi.delete_all(:auth, OAuth.Authorization.delete_by_user_query(user))

    case Repo.transaction(multi) do
      {:ok, %{user: user} = _} -> set_cache(user)
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  def register_changeset(struct, params \\ %{}, opts \\ []) do
    bio_limit = Pleroma.Config.get([:instance, :user_bio_length], 5000)
    name_limit = Pleroma.Config.get([:instance, :user_name_length], 100)

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
      |> validate_exclusion(:nickname, Pleroma.Config.get([User, :restricted_nicknames]))
      |> validate_format(:nickname, local_nickname_regex())
      |> validate_format(:email, @email_regex)
      |> validate_length(:bio, max: bio_limit)
      |> validate_length(:name, min: 1, max: name_limit)
      |> put_change(:info, info_change)

    changeset =
      if opts[:external] do
        changeset
      else
        validate_required(changeset, [:email])
      end

    if changeset.valid? do
      ap_id = User.ap_id(%User{nickname: changeset.changes[:nickname]})
      followers = User.ap_followers(%User{nickname: changeset.changes[:nickname]})

      changeset
      |> put_password_hash
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
      User.Query.build(%{nickname: candidates, local: true, deactivated: false})
      |> Repo.all()

    follow_all(user, autofollowed_users)
  end

  @doc "Inserts provided changeset, performs post-registration actions (confirmation email sending etc.)"
  def register(%Ecto.Changeset{} = changeset) do
    with {:ok, user} <- Repo.insert(changeset),
         {:ok, user} <- post_register_action(user) do
      {:ok, user}
    end
  end

  def post_register_action(%User{} = user) do
    with {:ok, user} <- autofollow_users(user),
         {:ok, user} <- set_cache(user),
         {:ok, _} <- User.WelcomeMessage.post_welcome_message_to_user(user),
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

  @spec maybe_direct_follow(User.t(), User.t()) :: {:ok, User.t()} | {:error, String.t()}
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
    deny_follow_blocked = Pleroma.Config.get([:user, :deny_follow_blocked])
    ap_followers = followed.follower_address

    cond do
      info.deactivated ->
        {:error, "Could not follow user: You are deactivated."}

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

        follower = maybe_update_following_count(follower)

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

      follower = maybe_update_following_count(follower)

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

  def locked?(%User{} = user) do
    user.info.locked || false
  end

  def get_by_id(id) do
    Repo.get_by(User, id: id)
  end

  def get_by_ap_id(ap_id) do
    Repo.get_by(User, ap_id: ap_id)
  end

  def get_all_by_ap_id(ap_ids) do
    from(u in __MODULE__,
      where: u.ap_id in ^ap_ids
    )
    |> Repo.all()
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
    with {:ok, user} <- Repo.update(changeset, stale_error_field: :id) do
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

  def get_cached_by_nickname_or_id(nickname_or_id, opts \\ []) do
    restrict_to_local = Pleroma.Config.get([:instance, :limit_to_local_content])

    cond do
      is_integer(nickname_or_id) or FlakeId.flake_id?(nickname_or_id) ->
        get_cached_by_id(nickname_or_id) || get_cached_by_nickname(nickname_or_id)

      restrict_to_local == false or not String.contains?(nickname_or_id, "@") ->
        get_cached_by_nickname(nickname_or_id)

      restrict_to_local == :unauthenticated and match?(%User{}, opts[:for]) ->
        get_cached_by_nickname(nickname_or_id)

      true ->
        nil
    end
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
    User.Query.build(%{followers: user, deactivated: false})
  end

  def get_followers_query(user, page) do
    from(u in get_followers_query(user, nil))
    |> User.Query.paginate(page, 20)
  end

  @spec get_followers_query(User.t()) :: Ecto.Query.t()
  def get_followers_query(user), do: get_followers_query(user, nil)

  @spec get_followers(User.t(), pos_integer()) :: {:ok, list(User.t())}
  def get_followers(user, page \\ nil) do
    q = get_followers_query(user, page)

    {:ok, Repo.all(q)}
  end

  @spec get_external_followers(User.t(), pos_integer()) :: {:ok, list(User.t())}
  def get_external_followers(user, page \\ nil) do
    q =
      user
      |> get_followers_query(page)
      |> User.Query.build(%{external: true})

    {:ok, Repo.all(q)}
  end

  def get_followers_ids(user, page \\ nil) do
    q = get_followers_query(user, page)

    Repo.all(from(u in q, select: u.id))
  end

  @spec get_friends_query(User.t(), pos_integer() | nil) :: Ecto.Query.t()
  def get_friends_query(%User{} = user, nil) do
    User.Query.build(%{friends: user, deactivated: false})
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
            "safe_jsonb_set(?, '{note_count}', ((?->>'note_count')::int + 1)::varchar::jsonb, true)",
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
            "safe_jsonb_set(?, '{note_count}', (greatest(0, (?->>'note_count')::int - 1))::varchar::jsonb, true)",
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

    user
    |> change()
    |> put_embed(:info, info_cng)
    |> update_and_set_cache()
  end

  @spec maybe_fetch_follow_information(User.t()) :: User.t()
  def maybe_fetch_follow_information(user) do
    with {:ok, user} <- fetch_follow_information(user) do
      user
    else
      e ->
        Logger.error("Follower/Following counter update for #{user.ap_id} failed.\n#{inspect(e)}")

        user
    end
  end

  def fetch_follow_information(user) do
    with {:ok, info} <- ActivityPub.fetch_follow_information_for_user(user) do
      info_cng = User.Info.follow_information_update(user.info, info)

      changeset =
        user
        |> change()
        |> put_embed(:info, info_cng)

      update_and_set_cache(changeset)
    else
      {:error, _} = e -> e
      e -> {:error, e}
    end
  end

  def update_follower_count(%User{} = user) do
    if user.local or !Pleroma.Config.get([:instance, :external_user_synchronization]) do
      follower_count_query =
        User.Query.build(%{followers: user, deactivated: false})
        |> select([u], %{count: count(u.id)})

      User
      |> where(id: ^user.id)
      |> join(:inner, [u], s in subquery(follower_count_query))
      |> update([u, s],
        set: [
          info:
            fragment(
              "safe_jsonb_set(?, '{follower_count}', ?::varchar::jsonb, true)",
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
    else
      {:ok, maybe_fetch_follow_information(user)}
    end
  end

  @spec maybe_update_following_count(User.t()) :: User.t()
  def maybe_update_following_count(%User{local: false} = user) do
    if Pleroma.Config.get([:instance, :external_user_synchronization]) do
      maybe_fetch_follow_information(user)
    else
      user
    end
  end

  def maybe_update_following_count(user), do: user

  def remove_duplicated_following(%User{following: following} = user) do
    uniq_following = Enum.uniq(following)

    if length(following) == length(uniq_following) do
      {:ok, user}
    else
      user
      |> update_changeset(%{following: uniq_following})
      |> update_and_set_cache()
    end
  end

  @spec get_users_from_set([String.t()], boolean()) :: [User.t()]
  def get_users_from_set(ap_ids, local_only \\ true) do
    criteria = %{ap_id: ap_ids, deactivated: false}
    criteria = if local_only, do: Map.put(criteria, :local, true), else: criteria

    User.Query.build(criteria)
    |> Repo.all()
  end

  @spec get_recipients_from_activity(Activity.t()) :: [User.t()]
  def get_recipients_from_activity(%Activity{recipients: to}) do
    User.Query.build(%{recipients_from_activity: to, local: true, deactivated: false})
    |> Repo.all()
  end

  @spec mute(User.t(), User.t(), boolean()) :: {:ok, User.t()} | {:error, String.t()}
  def mute(muter, %User{ap_id: ap_id}, notifications? \\ true) do
    info = muter.info

    info_cng =
      User.Info.add_to_mutes(info, ap_id)
      |> User.Info.add_to_muted_notifications(info, ap_id, notifications?)

    cng =
      change(muter)
      |> put_embed(:info, info_cng)

    update_and_set_cache(cng)
  end

  def unmute(muter, %{ap_id: ap_id}) do
    info = muter.info

    info_cng =
      User.Info.remove_from_mutes(info, ap_id)
      |> User.Info.remove_from_muted_notifications(info, ap_id)

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

    # clear any requested follows as well
    blocked =
      case CommonAPI.reject_follow_request(blocked, blocker) do
        {:ok, %User{} = updated_blocked} -> updated_blocked
        nil -> blocked
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

  @spec muted_notifications?(User.t() | nil, User.t() | map()) :: boolean()
  def muted_notifications?(nil, _), do: false

  def muted_notifications?(user, %{ap_id: ap_id}),
    do: Enum.member?(user.info.muted_notifications, ap_id)

  def blocks?(%User{} = user, %User{} = target) do
    blocks_ap_id?(user, target) || blocks_domain?(user, target)
  end

  def blocks?(nil, _), do: false

  def blocks_ap_id?(%User{} = user, %User{} = target) do
    Enum.member?(user.info.blocks, target.ap_id)
  end

  def blocks_ap_id?(_, _), do: false

  def blocks_domain?(%User{} = user, %User{} = target) do
    domain_blocks = Pleroma.Web.ActivityPub.MRF.subdomains_regex(user.info.domain_blocks)
    %{host: host} = URI.parse(target.ap_id)
    Pleroma.Web.ActivityPub.MRF.subdomain_match?(domain_blocks, host)
  end

  def blocks_domain?(_, _), do: false

  def subscribed_to?(user, %{ap_id: ap_id}) do
    with %User{} = target <- get_cached_by_ap_id(ap_id) do
      Enum.member?(target.info.subscribers, user.ap_id)
    end
  end

  @spec muted_users(User.t()) :: [User.t()]
  def muted_users(user) do
    User.Query.build(%{ap_id: user.info.mutes, deactivated: false})
    |> Repo.all()
  end

  @spec blocked_users(User.t()) :: [User.t()]
  def blocked_users(user) do
    User.Query.build(%{ap_id: user.info.blocks, deactivated: false})
    |> Repo.all()
  end

  @spec subscribers(User.t()) :: [User.t()]
  def subscribers(user) do
    User.Query.build(%{ap_id: user.info.subscribers, deactivated: false})
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

  def deactivate_async(user, status \\ true) do
    PleromaJobQueue.enqueue(:background, __MODULE__, [:deactivate_async, user, status])
  end

  def deactivate(%User{} = user, status \\ true) do
    info_cng = User.Info.set_activation_status(user.info, status)

    with {:ok, friends} <- User.get_friends(user),
         {:ok, followers} <- User.get_followers(user),
         {:ok, user} <-
           user
           |> change()
           |> put_embed(:info, info_cng)
           |> update_and_set_cache() do
      Enum.each(followers, &invalidate_cache(&1))
      Enum.each(friends, &update_follower_count(&1))

      {:ok, user}
    end
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
    {:ok, _user} = ActivityPub.delete(user)

    # Remove all relationships
    {:ok, followers} = User.get_followers(user)

    Enum.each(followers, fn follower ->
      ActivityPub.unfollow(follower, user)
      User.unfollow(follower, user)
    end)

    {:ok, friends} = User.get_friends(user)

    Enum.each(friends, fn followed ->
      ActivityPub.unfollow(user, followed)
      User.unfollow(user, followed)
    end)

    delete_user_activities(user)
    invalidate_cache(user)
    Repo.delete(user)
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

  def perform(:deactivate_async, user, status), do: deactivate(user, status)

  @spec perform(atom(), User.t(), list()) :: list() | {:error, any()}
  def perform(:blocks_import, %User{} = blocker, blocked_identifiers)
      when is_list(blocked_identifiers) do
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

  @spec perform(atom(), User.t(), list()) :: list() | {:error, any()}
  def perform(:follow_import, %User{} = follower, followed_identifiers)
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

  @spec external_users_query() :: Ecto.Query.t()
  def external_users_query do
    User.Query.build(%{
      external: true,
      active: true,
      order_by: :id
    })
  end

  @spec external_users(keyword()) :: [User.t()]
  def external_users(opts \\ []) do
    query =
      external_users_query()
      |> select([u], struct(u, [:id, :ap_id, :info]))

    query =
      if opts[:max_id],
        do: where(query, [u], u.id > ^opts[:max_id]),
        else: query

    query =
      if opts[:limit],
        do: limit(query, ^opts[:limit]),
        else: query

    Repo.all(query)
  end

  def blocks_import(%User{} = blocker, blocked_identifiers) when is_list(blocked_identifiers),
    do:
      PleromaJobQueue.enqueue(:background, __MODULE__, [
        :blocks_import,
        blocker,
        blocked_identifiers
      ])

  def follow_import(%User{} = follower, followed_identifiers) when is_list(followed_identifiers),
    do:
      PleromaJobQueue.enqueue(:background, __MODULE__, [
        :follow_import,
        follower,
        followed_identifiers
      ])

  def delete_user_activities(%User{ap_id: ap_id} = user) do
    ap_id
    |> Activity.Queries.by_actor()
    |> RepoStreamer.chunk_stream(50)
    |> Stream.each(fn activities ->
      Enum.each(activities, &delete_activity(&1))
    end)
    |> Stream.run()

    {:ok, user}
  end

  defp delete_activity(%{data: %{"type" => "Create"}} = activity) do
    activity
    |> Object.normalize()
    |> ActivityPub.delete()
  end

  defp delete_activity(%{data: %{"type" => "Like"}} = activity) do
    user = get_cached_by_ap_id(activity.actor)
    object = Object.normalize(activity)

    ActivityPub.unlike(user, object)
  end

  defp delete_activity(%{data: %{"type" => "Announce"}} = activity) do
    user = get_cached_by_ap_id(activity.actor)
    object = Object.normalize(activity)

    ActivityPub.unannounce(user, object)
  end

  defp delete_activity(_activity), do: "Doing nothing"

  def html_filter_policy(%User{info: %{no_rich_text: true}}) do
    Pleroma.HTML.Scrubber.TwitterText
  end

  def html_filter_policy(_), do: Pleroma.Config.get([:markup, :scrub_policy])

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

  @doc "Creates an internal service actor by URI if missing.  Optionally takes nickname for addressing."
  def get_or_create_service_actor_by_ap_id(uri, nickname \\ nil) do
    if user = get_cached_by_ap_id(uri) do
      user
    else
      changes =
        %User{info: %User.Info{}}
        |> cast(%{}, [:ap_id, :nickname, :local])
        |> put_change(:ap_id, uri)
        |> put_change(:nickname, nickname)
        |> put_change(:local, true)
        |> put_change(:follower_address, uri <> "/followers")

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
  def public_key_from_info(%{magic_key: magic_key}) when not is_nil(magic_key) do
    {:ok, Pleroma.Web.Salmon.decode_key(magic_key)}
  end

  def public_key_from_info(_), do: {:error, "not found key"}

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
    |> Repo.insert(on_conflict: :replace_all_except_primary_key, conflict_target: :nickname)
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
    User.Query.build(%{super_users: true, local: true, deactivated: false})
    |> Repo.all()
  end

  def showing_reblogs?(%User{} = user, %User{} = target) do
    target.ap_id not in user.info.muted_reblogs
  end

  @doc """
  The function returns a query to get users with no activity for given interval of days.
  Inactive users are those who didn't read any notification, or had any activity where
  the user is the activity's actor, during `inactivity_threshold` days.
  Deactivated users will not appear in this list.

  ## Examples

      iex> Pleroma.User.list_inactive_users()
      %Ecto.Query{}
  """
  @spec list_inactive_users_query(integer()) :: Ecto.Query.t()
  def list_inactive_users_query(inactivity_threshold \\ 7) do
    negative_inactivity_threshold = -inactivity_threshold
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    # Subqueries are not supported in `where` clauses, join gets too complicated.
    has_read_notifications =
      from(n in Pleroma.Notification,
        where: n.seen == true,
        group_by: n.id,
        having: max(n.updated_at) > datetime_add(^now, ^negative_inactivity_threshold, "day"),
        select: n.user_id
      )
      |> Pleroma.Repo.all()

    from(u in Pleroma.User,
      left_join: a in Pleroma.Activity,
      on: u.ap_id == a.actor,
      where: not is_nil(u.nickname),
      where: fragment("not (?->'deactivated' @> 'true')", u.info),
      where: u.id not in ^has_read_notifications,
      group_by: u.id,
      having:
        max(a.inserted_at) < datetime_add(^now, ^negative_inactivity_threshold, "day") or
          is_nil(max(a.inserted_at))
    )
  end

  @doc """
  Enable or disable email notifications for user

  ## Examples

      iex> Pleroma.User.switch_email_notifications(Pleroma.User{info: %{email_notifications: %{"digest" => false}}}, "digest", true)
      Pleroma.User{info: %{email_notifications: %{"digest" => true}}}

      iex> Pleroma.User.switch_email_notifications(Pleroma.User{info: %{email_notifications: %{"digest" => true}}}, "digest", false)
      Pleroma.User{info: %{email_notifications: %{"digest" => false}}}
  """
  @spec switch_email_notifications(t(), String.t(), boolean()) ::
          {:ok, t()} | {:error, Ecto.Changeset.t()}
  def switch_email_notifications(user, type, status) do
    info = Pleroma.User.Info.update_email_notifications(user.info, %{type => status})

    change(user)
    |> put_embed(:info, info)
    |> update_and_set_cache()
  end

  @doc """
  Set `last_digest_emailed_at` value for the user to current time
  """
  @spec touch_last_digest_emailed_at(t()) :: t()
  def touch_last_digest_emailed_at(user) do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    {:ok, updated_user} =
      user
      |> change(%{last_digest_emailed_at: now})
      |> update_and_set_cache()

    updated_user
  end

  @spec toggle_confirmation(User.t()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def toggle_confirmation(%User{} = user) do
    need_confirmation? = !user.info.confirmation_pending

    info_changeset =
      User.Info.confirmation_changeset(user.info, need_confirmation: need_confirmation?)

    user
    |> change()
    |> put_embed(:info, info_changeset)
    |> update_and_set_cache()
  end

  def get_mascot(%{info: %{mascot: %{} = mascot}}) when not is_nil(mascot) do
    mascot
  end

  def get_mascot(%{info: %{mascot: mascot}}) when is_nil(mascot) do
    # use instance-default
    config = Pleroma.Config.get([:assets, :mascots])
    default_mascot = Pleroma.Config.get([:assets, :default_mascot])
    mascot = Keyword.get(config, default_mascot)

    %{
      "id" => "default-mascot",
      "url" => mascot[:url],
      "preview_url" => mascot[:url],
      "pleroma" => %{
        "mime_type" => mascot[:mime_type]
      }
    }
  end

  def ensure_keys_present(%{keys: keys} = user) when not is_nil(keys), do: {:ok, user}

  def ensure_keys_present(%User{} = user) do
    with {:ok, pem} <- Keys.generate_rsa_pem() do
      user
      |> cast(%{keys: pem}, [:keys])
      |> validate_required([:keys])
      |> update_and_set_cache()
    end
  end

  def get_ap_ids_by_nicknames(nicknames) do
    from(u in User,
      where: u.nickname in ^nicknames,
      select: u.ap_id
    )
    |> Repo.all()
  end

  defdelegate search(query, opts \\ []), to: User.Search

  defp put_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    change(changeset, password_hash: Pbkdf2.hashpwsalt(password))
  end

  defp put_password_hash(changeset), do: changeset

  def is_internal_user?(%User{nickname: nil}), do: true
  def is_internal_user?(%User{local: true, nickname: "internal." <> _}), do: true
  def is_internal_user?(_), do: false

  def change_email(user, email) do
    user
    |> cast(%{email: email}, [:email])
    |> validate_required([:email])
    |> unique_constraint(:email)
    |> validate_format(:email, @email_regex)
    |> update_and_set_cache()
  end
end
