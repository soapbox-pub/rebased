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
  alias Pleroma.Conversation.Participation
  alias Pleroma.Delivery
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
  alias Pleroma.Web.RelMe
  alias Pleroma.Workers.BackgroundWorker

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

    field(:banner, :map, default: %{})
    field(:background, :map, default: %{})
    field(:source_data, :map, default: %{})
    field(:note_count, :integer, default: 0)
    field(:follower_count, :integer, default: 0)
    # Should be filled in only for remote users
    field(:following_count, :integer, default: nil)
    field(:locked, :boolean, default: false)
    field(:confirmation_pending, :boolean, default: false)
    field(:password_reset_pending, :boolean, default: false)
    field(:confirmation_token, :string, default: nil)
    field(:default_scope, :string, default: "public")
    field(:blocks, {:array, :string}, default: [])
    field(:domain_blocks, {:array, :string}, default: [])
    field(:mutes, {:array, :string}, default: [])
    field(:muted_reblogs, {:array, :string}, default: [])
    field(:muted_notifications, {:array, :string}, default: [])
    field(:subscribers, {:array, :string}, default: [])
    field(:deactivated, :boolean, default: false)
    field(:no_rich_text, :boolean, default: false)
    field(:ap_enabled, :boolean, default: false)
    field(:is_moderator, :boolean, default: false)
    field(:is_admin, :boolean, default: false)
    field(:show_role, :boolean, default: true)
    field(:settings, :map, default: nil)
    field(:magic_key, :string, default: nil)
    field(:uri, :string, default: nil)
    field(:hide_followers_count, :boolean, default: false)
    field(:hide_follows_count, :boolean, default: false)
    field(:hide_followers, :boolean, default: false)
    field(:hide_follows, :boolean, default: false)
    field(:hide_favorites, :boolean, default: true)
    field(:unread_conversation_count, :integer, default: 0)
    field(:pinned_activities, {:array, :string}, default: [])
    field(:email_notifications, :map, default: %{"digest" => false})
    field(:mascot, :map, default: nil)
    field(:emoji, {:array, :map}, default: [])
    field(:pleroma_settings_store, :map, default: %{})
    field(:fields, {:array, :map}, default: [])
    field(:raw_fields, {:array, :map}, default: [])
    field(:discoverable, :boolean, default: false)
    field(:invisible, :boolean, default: false)
    field(:skip_thread_containment, :boolean, default: false)

    field(:notification_settings, :map,
      default: %{
        "followers" => true,
        "follows" => true,
        "non_follows" => true,
        "non_followers" => true
      }
    )

    has_many(:notifications, Notification)
    has_many(:registrations, Registration)
    has_many(:deliveries, Delivery)

    field(:info, :map, default: %{})

    timestamps()
  end

  def auth_active?(%User{confirmation_pending: true}),
    do: !Pleroma.Config.get([:instance, :account_activation_required])

  def auth_active?(%User{}), do: true

  def visible_for?(user, for_user \\ nil)

  def visible_for?(%User{id: user_id}, %User{id: for_id}) when user_id == for_id, do: true

  def visible_for?(%User{} = user, for_user) do
    auth_active?(user) || superuser?(for_user)
  end

  def visible_for?(_, _), do: false

  def superuser?(%User{local: true, is_admin: true}), do: true
  def superuser?(%User{local: true, is_moderator: true}), do: true
  def superuser?(_), do: false

  def invisible?(%User{invisible: true}), do: true
  def invisible?(_), do: false

  def avatar_url(user, options \\ []) do
    case user.avatar do
      %{"url" => [%{"href" => href} | _]} -> href
      _ -> !options[:no_default] && "#{Web.base_url()}/images/avi.png"
    end
  end

  def banner_url(user, options \\ []) do
    case user.banner do
      %{"url" => [%{"href" => href} | _]} -> href
      _ -> !options[:no_default] && "#{Web.base_url()}/images/banner.png"
    end
  end

  def profile_url(%User{source_data: %{"url" => url}}), do: url
  def profile_url(%User{ap_id: ap_id}), do: ap_id
  def profile_url(_), do: nil

  def ap_id(%User{nickname: nickname}), do: "#{Web.base_url()}/users/#{nickname}"

  def ap_followers(%User{follower_address: fa}) when is_binary(fa), do: fa
  def ap_followers(%User{} = user), do: "#{ap_id(user)}/followers"

  @spec ap_following(User.t()) :: Sring.t()
  def ap_following(%User{following_address: fa}) when is_binary(fa), do: fa
  def ap_following(%User{} = user), do: "#{ap_id(user)}/following"

  def user_info(%User{} = user, args \\ %{}) do
    following_count =
      Map.get(args, :following_count, user.following_count || following_count(user))

    follower_count = Map.get(args, :follower_count, user.follower_count)

    %{
      note_count: user.note_count,
      locked: user.locked,
      confirmation_pending: user.confirmation_pending,
      default_scope: user.default_scope
    }
    |> Map.put(:following_count, following_count)
    |> Map.put(:follower_count, follower_count)
  end

  def follow_state(%User{} = user, %User{} = target) do
    case Utils.fetch_latest_follow(user, target) do
      %{data: %{"state" => state}} -> state
      # Ideally this would be nil, but then Cachex does not commit the value
      _ -> false
    end
  end

  def get_cached_follow_state(user, target) do
    key = "follow_state:#{user.ap_id}|#{target.ap_id}"
    Cachex.fetch!(:user_cache, key, fn _ -> {:commit, follow_state(user, target)} end)
  end

  @spec set_follow_state_cache(String.t(), String.t(), String.t()) :: {:ok | :error, boolean()}
  def set_follow_state_cache(user_ap_id, target_ap_id, state) do
    Cachex.put(:user_cache, "follow_state:#{user_ap_id}|#{target_ap_id}", state)
  end

  def set_info_cache(user, args) do
    Cachex.put(:user_cache, "user_info:#{user.id}", user_info(user, args))
  end

  @spec restrict_deactivated(Ecto.Query.t()) :: Ecto.Query.t()
  def restrict_deactivated(query) do
    from(u in query, where: u.deactivated != ^true)
  end

  def following_count(%User{following: []}), do: 0

  def following_count(%User{} = user) do
    user
    |> get_friends_query()
    |> Repo.aggregate(:count, :id)
  end

  defp truncate_fields_param(params) do
    if Map.has_key?(params, :fields) do
      Map.put(params, :fields, Enum.map(params[:fields], &truncate_field/1))
    else
      params
    end
  end

  defp truncate_if_exists(params, key, max_length) do
    if Map.has_key?(params, key) and is_binary(params[key]) do
      {value, _chopped} = String.split_at(params[key], max_length)
      Map.put(params, key, value)
    else
      params
    end
  end

  def remote_user_creation(params) do
    bio_limit = Pleroma.Config.get([:instance, :user_bio_length], 5000)
    name_limit = Pleroma.Config.get([:instance, :user_name_length], 100)

    params =
      params
      |> Map.put(:info, params[:info] || %{})
      |> truncate_if_exists(:name, name_limit)
      |> truncate_if_exists(:bio, bio_limit)
      |> truncate_fields_param()

    changeset =
      %User{local: false}
      |> cast(
        params,
        [
          :bio,
          :name,
          :ap_id,
          :nickname,
          :avatar,
          :ap_enabled,
          :source_data,
          :banner,
          :locked,
          :magic_key,
          :uri,
          :hide_followers,
          :hide_follows,
          :hide_followers_count,
          :hide_follows_count,
          :follower_count,
          :fields,
          :following_count,
          :discoverable,
          :invisible
        ]
      )
      |> validate_required([:name, :ap_id])
      |> unique_constraint(:nickname)
      |> validate_format(:nickname, @email_regex)
      |> validate_length(:bio, max: bio_limit)
      |> validate_length(:name, max: name_limit)
      |> validate_fields(true)

    case params[:source_data] do
      %{"followers" => followers, "following" => following} ->
        changeset
        |> put_change(:follower_address, followers)
        |> put_change(:following_address, following)

      _ ->
        followers = ap_followers(%User{nickname: get_field(changeset, :nickname)})
        put_change(changeset, :follower_address, followers)
    end
  end

  def update_changeset(struct, params \\ %{}) do
    bio_limit = Pleroma.Config.get([:instance, :user_bio_length], 5000)
    name_limit = Pleroma.Config.get([:instance, :user_name_length], 100)

    struct
    |> cast(
      params,
      [
        :bio,
        :name,
        :avatar,
        :following,
        :locked,
        :no_rich_text,
        :default_scope,
        :banner,
        :hide_follows,
        :hide_followers,
        :hide_followers_count,
        :hide_follows_count,
        :hide_favorites,
        :background,
        :show_role,
        :skip_thread_containment,
        :fields,
        :raw_fields,
        :pleroma_settings_store,
        :discoverable
      ]
    )
    |> unique_constraint(:nickname)
    |> validate_format(:nickname, local_nickname_regex())
    |> validate_length(:bio, max: bio_limit)
    |> validate_length(:name, min: 1, max: name_limit)
    |> validate_fields(false)
  end

  def upgrade_changeset(struct, params \\ %{}, remote? \\ false) do
    bio_limit = Pleroma.Config.get([:instance, :user_bio_length], 5000)
    name_limit = Pleroma.Config.get([:instance, :user_name_length], 100)

    params = Map.put(params, :last_refreshed_at, NaiveDateTime.utc_now())

    params = if remote?, do: truncate_fields_param(params), else: params

    struct
    |> cast(
      params,
      [
        :bio,
        :name,
        :follower_address,
        :following_address,
        :avatar,
        :last_refreshed_at,
        :ap_enabled,
        :source_data,
        :banner,
        :locked,
        :magic_key,
        :follower_count,
        :following_count,
        :hide_follows,
        :fields,
        :hide_followers,
        :discoverable,
        :hide_followers_count,
        :hide_follows_count
      ]
    )
    |> unique_constraint(:nickname)
    |> validate_format(:nickname, local_nickname_regex())
    |> validate_length(:bio, max: bio_limit)
    |> validate_length(:name, max: name_limit)
    |> validate_fields(remote?)
  end

  def password_update_changeset(struct, params) do
    struct
    |> cast(params, [:password, :password_confirmation])
    |> validate_required([:password, :password_confirmation])
    |> validate_confirmation(:password)
    |> put_password_hash()
    |> put_change(:password_reset_pending, false)
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

  def update_password_reset_pending(user, value) do
    user
    |> change()
    |> put_change(:password_reset_pending, value)
    |> update_and_set_cache()
  end

  def force_password_reset_async(user) do
    BackgroundWorker.enqueue("force_password_reset", %{"user_id" => user.id})
  end

  @spec force_password_reset(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def force_password_reset(user), do: update_password_reset_pending(user, true)

  def register_changeset(struct, params \\ %{}, opts \\ []) do
    bio_limit = Pleroma.Config.get([:instance, :user_bio_length], 5000)
    name_limit = Pleroma.Config.get([:instance, :user_name_length], 100)

    need_confirmation? =
      if is_nil(opts[:need_confirmation]) do
        Pleroma.Config.get([:instance, :account_activation_required])
      else
        opts[:need_confirmation]
      end

    struct
    |> confirmation_changeset(need_confirmation: need_confirmation?)
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
    |> maybe_validate_required_email(opts[:external])
    |> put_password_hash
    |> put_ap_id()
    |> unique_constraint(:ap_id)
    |> put_following_and_follower_address()
  end

  def maybe_validate_required_email(changeset, true), do: changeset
  def maybe_validate_required_email(changeset, _), do: validate_required(changeset, [:email])

  defp put_ap_id(changeset) do
    ap_id = ap_id(%User{nickname: get_field(changeset, :nickname)})
    put_change(changeset, :ap_id, ap_id)
  end

  defp put_following_and_follower_address(changeset) do
    followers = ap_followers(%User{nickname: get_field(changeset, :nickname)})

    changeset
    |> put_change(:following, [followers])
    |> put_change(:follower_address, followers)
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
    with {:ok, user} <- Repo.insert(changeset) do
      post_register_action(user)
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
    if user.confirmation_pending &&
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
  def maybe_direct_follow(%User{} = follower, %User{local: true, locked: true}) do
    {:ok, follower}
  end

  def maybe_direct_follow(%User{} = follower, %User{local: true} = followed) do
    follow(follower, followed)
  end

  def maybe_direct_follow(%User{} = follower, %User{} = followed) do
    if not ap_enabled?(followed) do
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

    Enum.each(followeds, &update_follower_count/1)

    set_cache(follower)
  end

  def follow(%User{} = follower, %User{} = followed) do
    deny_follow_blocked = Pleroma.Config.get([:user, :deny_follow_blocked])
    ap_followers = followed.follower_address

    cond do
      followed.deactivated ->
        {:error, "Could not follow user: #{followed.nickname} is deactivated."}

      deny_follow_blocked and blocks?(followed, follower) ->
        {:error, "Could not follow user: #{followed.nickname} blocked you."}

      true ->
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
    user.locked || false
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

  def get_all_by_ids(ids) do
    from(u in __MODULE__, where: u.id in ^ids)
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

  def update_and_set_cache(struct, params) do
    struct
    |> update_changeset(params)
    |> update_and_set_cache()
  end

  def update_and_set_cache(changeset) do
    with {:ok, user} <- Repo.update(changeset, stale_error_field: :id) do
      set_cache(user)
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
      case get_or_fetch_by_nickname(nickname) do
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
    Cachex.fetch!(:user_cache, key, fn -> user_info(user) end)
  end

  def fetch_by_nickname(nickname), do: ActivityPub.make_user_from_nickname(nickname)

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
  def fetch_initial_posts(user) do
    BackgroundWorker.enqueue("fetch_initial_posts", %{"user_id" => user.id})
  end

  @spec get_followers_query(User.t(), pos_integer() | nil) :: Ecto.Query.t()
  def get_followers_query(%User{} = user, nil) do
    User.Query.build(%{followers: user, deactivated: false})
  end

  def get_followers_query(user, page) do
    user
    |> get_followers_query(nil)
    |> User.Query.paginate(page, 20)
  end

  @spec get_followers_query(User.t()) :: Ecto.Query.t()
  def get_followers_query(user), do: get_followers_query(user, nil)

  @spec get_followers(User.t(), pos_integer()) :: {:ok, list(User.t())}
  def get_followers(user, page \\ nil) do
    user
    |> get_followers_query(page)
    |> Repo.all()
  end

  @spec get_external_followers(User.t(), pos_integer()) :: {:ok, list(User.t())}
  def get_external_followers(user, page \\ nil) do
    user
    |> get_followers_query(page)
    |> User.Query.build(%{external: true})
    |> Repo.all()
  end

  def get_followers_ids(user, page \\ nil) do
    user
    |> get_followers_query(page)
    |> select([u], u.id)
    |> Repo.all()
  end

  @spec get_friends_query(User.t(), pos_integer() | nil) :: Ecto.Query.t()
  def get_friends_query(%User{} = user, nil) do
    User.Query.build(%{friends: user, deactivated: false})
  end

  def get_friends_query(user, page) do
    user
    |> get_friends_query(nil)
    |> User.Query.paginate(page, 20)
  end

  @spec get_friends_query(User.t()) :: Ecto.Query.t()
  def get_friends_query(user), do: get_friends_query(user, nil)

  def get_friends(user, page \\ nil) do
    user
    |> get_friends_query(page)
    |> Repo.all()
  end

  def get_friends_ids(user, page \\ nil) do
    user
    |> get_friends_query(page)
    |> select([u], u.id)
    |> Repo.all()
  end

  @spec get_follow_requests(User.t()) :: {:ok, [User.t()]}
  def get_follow_requests(%User{} = user) do
    user
    |> Activity.follow_requests_for_actor()
    |> join(:inner, [a], u in User, on: a.actor == u.ap_id)
    |> where([a, u], not fragment("? @> ?", u.following, ^[user.follower_address]))
    |> group_by([a, u], u.id)
    |> select([a, u], u)
    |> Repo.all()
  end

  def increase_note_count(%User{} = user) do
    User
    |> where(id: ^user.id)
    |> update([u], inc: [note_count: 1])
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
        note_count: fragment("greatest(0, note_count - 1)")
      ]
    )
    |> select([u], u)
    |> Repo.update_all([])
    |> case do
      {1, [user]} -> set_cache(user)
      _ -> {:error, user}
    end
  end

  def update_note_count(%User{} = user, note_count \\ nil) do
    note_count =
      note_count ||
        from(
          a in Object,
          where: fragment("?->>'actor' = ? and ?->>'type' = 'Note'", a.data, ^user.ap_id, a.data),
          select: count(a.id)
        )
        |> Repo.one()

    user
    |> cast(%{note_count: note_count}, [:note_count])
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
      user
      |> follow_information_changeset(info)
      |> update_and_set_cache()
    end
  end

  defp follow_information_changeset(user, params) do
    user
    |> cast(params, [
      :hide_followers,
      :hide_follows,
      :follower_count,
      :following_count,
      :hide_followers_count,
      :hide_follows_count
    ])
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
        set: [follower_count: s.count]
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

  def set_unread_conversation_count(%User{local: true} = user) do
    unread_query = Participation.unread_conversation_count_for_user(user)

    User
    |> join(:inner, [u], p in subquery(unread_query))
    |> update([u, p],
      set: [unread_conversation_count: p.count]
    )
    |> where([u], u.id == ^user.id)
    |> select([u], u)
    |> Repo.update_all([])
    |> case do
      {1, [user]} -> set_cache(user)
      _ -> {:error, user}
    end
  end

  def set_unread_conversation_count(_), do: :noop

  def increment_unread_conversation_count(conversation, %User{local: true} = user) do
    unread_query =
      Participation.unread_conversation_count_for_user(user)
      |> where([p], p.conversation_id == ^conversation.id)

    User
    |> join(:inner, [u], p in subquery(unread_query))
    |> update([u, p],
      inc: [unread_conversation_count: 1]
    )
    |> where([u], u.id == ^user.id)
    |> where([u, p], p.count == 0)
    |> select([u], u)
    |> Repo.update_all([])
    |> case do
      {1, [user]} -> set_cache(user)
      _ -> {:error, user}
    end
  end

  def increment_unread_conversation_count(_, _), do: :noop

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
    add_to_mutes(muter, ap_id, notifications?)
  end

  def unmute(muter, %{ap_id: ap_id}) do
    remove_from_mutes(muter, ap_id)
  end

  def subscribe(subscriber, %{ap_id: ap_id}) do
    with %User{} = subscribed <- get_cached_by_ap_id(ap_id) do
      deny_follow_blocked = Pleroma.Config.get([:user, :deny_follow_blocked])

      if blocks?(subscribed, subscriber) and deny_follow_blocked do
        {:error, "Could not subscribe: #{subscribed.nickname} is blocking you"}
      else
        User.add_to_subscribers(subscribed, subscriber.ap_id)
      end
    end
  end

  def unsubscribe(unsubscriber, %{ap_id: ap_id}) do
    with %User{} = user <- get_cached_by_ap_id(ap_id) do
      User.remove_from_subscribers(user, unsubscriber.ap_id)
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

    if following?(blocked, blocker), do: unfollow(blocked, blocker)

    {:ok, blocker} = update_follower_count(blocker)

    add_to_block(blocker, ap_id)
  end

  # helper to handle the block given only an actor's AP id
  def block(blocker, %{ap_id: ap_id}) do
    block(blocker, get_cached_by_ap_id(ap_id))
  end

  def unblock(blocker, %{ap_id: ap_id}) do
    remove_from_block(blocker, ap_id)
  end

  def mutes?(nil, _), do: false
  def mutes?(user, %{ap_id: ap_id}), do: Enum.member?(user.mutes, ap_id)

  @spec muted_notifications?(User.t() | nil, User.t() | map()) :: boolean()
  def muted_notifications?(nil, _), do: false

  def muted_notifications?(user, %{ap_id: ap_id}),
    do: Enum.member?(user.muted_notifications, ap_id)

  def blocks?(%User{} = user, %User{} = target) do
    blocks_ap_id?(user, target) || blocks_domain?(user, target)
  end

  def blocks?(nil, _), do: false

  def blocks_ap_id?(%User{} = user, %User{} = target) do
    Enum.member?(user.blocks, target.ap_id)
  end

  def blocks_ap_id?(_, _), do: false

  def blocks_domain?(%User{} = user, %User{} = target) do
    domain_blocks = Pleroma.Web.ActivityPub.MRF.subdomains_regex(user.domain_blocks)
    %{host: host} = URI.parse(target.ap_id)
    Pleroma.Web.ActivityPub.MRF.subdomain_match?(domain_blocks, host)
  end

  def blocks_domain?(_, _), do: false

  def subscribed_to?(user, %{ap_id: ap_id}) do
    with %User{} = target <- get_cached_by_ap_id(ap_id) do
      Enum.member?(target.subscribers, user.ap_id)
    end
  end

  @spec muted_users(User.t()) :: [User.t()]
  def muted_users(user) do
    User.Query.build(%{ap_id: user.mutes, deactivated: false})
    |> Repo.all()
  end

  @spec blocked_users(User.t()) :: [User.t()]
  def blocked_users(user) do
    User.Query.build(%{ap_id: user.blocks, deactivated: false})
    |> Repo.all()
  end

  @spec subscribers(User.t()) :: [User.t()]
  def subscribers(user) do
    User.Query.build(%{ap_id: user.subscribers, deactivated: false})
    |> Repo.all()
  end

  def deactivate_async(user, status \\ true) do
    BackgroundWorker.enqueue("deactivate_user", %{"user_id" => user.id, "status" => status})
  end

  def deactivate(user, status \\ true)

  def deactivate(users, status) when is_list(users) do
    Repo.transaction(fn ->
      for user <- users, do: deactivate(user, status)
    end)
  end

  def deactivate(%User{} = user, status) do
    with {:ok, user} <- set_activation_status(user, status) do
      Enum.each(get_followers(user), &invalidate_cache/1)
      Enum.each(get_friends(user), &update_follower_count/1)

      {:ok, user}
    end
  end

  def update_notification_settings(%User{} = user, settings) do
    settings =
      settings
      |> Enum.map(fn {k, v} -> {k, v in [true, "true", "True", "1"]} end)
      |> Map.new()

    notification_settings =
      user.notification_settings
      |> Map.merge(settings)
      |> Map.take(["followers", "follows", "non_follows", "non_followers"])

    params = %{notification_settings: notification_settings}

    user
    |> cast(params, [:notification_settings])
    |> validate_required([:notification_settings])
    |> update_and_set_cache()
  end

  def delete(users) when is_list(users) do
    for user <- users, do: delete(user)
  end

  def delete(%User{} = user) do
    BackgroundWorker.enqueue("delete_user", %{"user_id" => user.id})
  end

  def perform(:force_password_reset, user), do: force_password_reset(user)

  @spec perform(atom(), User.t()) :: {:ok, User.t()}
  def perform(:delete, %User{} = user) do
    {:ok, _user} = ActivityPub.delete(user)

    # Remove all relationships
    user
    |> get_followers()
    |> Enum.each(fn follower ->
      ActivityPub.unfollow(follower, user)
      unfollow(follower, user)
    end)

    user
    |> get_friends()
    |> Enum.each(fn followed ->
      ActivityPub.unfollow(user, followed)
      unfollow(user, followed)
    end)

    delete_user_activities(user)
    invalidate_cache(user)
    Repo.delete(user)
  end

  @spec perform(atom(), User.t()) :: {:ok, User.t()}
  def perform(:fetch_initial_posts, %User{} = user) do
    pages = Pleroma.Config.get!([:fetch_initial_posts, :pages])

    # Insert all the posts in reverse order, so they're in the right order on the timeline
    user.source_data["outbox"]
    |> Utils.fetch_ordered_collection(pages)
    |> Enum.reverse()
    |> Enum.each(&Pleroma.Web.Federator.incoming_ap_doc/1)
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

  def blocks_import(%User{} = blocker, blocked_identifiers) when is_list(blocked_identifiers) do
    BackgroundWorker.enqueue("blocks_import", %{
      "blocker_id" => blocker.id,
      "blocked_identifiers" => blocked_identifiers
    })
  end

  def follow_import(%User{} = follower, followed_identifiers)
      when is_list(followed_identifiers) do
    BackgroundWorker.enqueue("follow_import", %{
      "follower_id" => follower.id,
      "followed_identifiers" => followed_identifiers
    })
  end

  def delete_user_activities(%User{ap_id: ap_id}) do
    ap_id
    |> Activity.Queries.by_actor()
    |> RepoStreamer.chunk_stream(50)
    |> Stream.each(fn activities -> Enum.each(activities, &delete_activity/1) end)
    |> Stream.run()
  end

  defp delete_activity(%{data: %{"type" => "Create"}} = activity) do
    activity
    |> Object.normalize()
    |> ActivityPub.delete()
  end

  defp delete_activity(%{data: %{"type" => "Like"}} = activity) do
    object = Object.normalize(activity)

    activity.actor
    |> get_cached_by_ap_id()
    |> ActivityPub.unlike(object)
  end

  defp delete_activity(%{data: %{"type" => "Announce"}} = activity) do
    object = Object.normalize(activity)

    activity.actor
    |> get_cached_by_ap_id()
    |> ActivityPub.unannounce(object)
  end

  defp delete_activity(_activity), do: "Doing nothing"

  def html_filter_policy(%User{no_rich_text: true}) do
    Pleroma.HTML.Scrubber.TwitterText
  end

  def html_filter_policy(_), do: Pleroma.Config.get([:markup, :scrub_policy])

  def fetch_by_ap_id(ap_id), do: ActivityPub.make_user_from_ap_id(ap_id)

  def get_or_fetch_by_ap_id(ap_id) do
    user = get_cached_by_ap_id(ap_id)

    if !is_nil(user) and !needs_update?(user) do
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
    with %User{} = user <- get_cached_by_ap_id(uri) do
      user
    else
      _ ->
        {:ok, user} =
          %User{}
          |> cast(%{}, [:ap_id, :nickname, :local])
          |> put_change(:ap_id, uri)
          |> put_change(:nickname, nickname)
          |> put_change(:local, true)
          |> put_change(:follower_address, uri <> "/followers")
          |> Repo.insert()

        user
    end
  end

  # AP style
  def public_key(%{source_data: %{"publicKey" => %{"publicKeyPem" => public_key_pem}}}) do
    key =
      public_key_pem
      |> :public_key.pem_decode()
      |> hd()
      |> :public_key.pem_entry_decode()

    {:ok, key}
  end

  def public_key(_), do: {:error, "not found key"}

  def get_public_key_for_ap_id(ap_id) do
    with {:ok, %User{} = user} <- get_or_fetch_by_ap_id(ap_id),
         {:ok, public_key} <- public_key(user) do
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
  def ap_enabled?(%User{ap_enabled: ap_enabled}), do: ap_enabled
  def ap_enabled?(_), do: false

  @doc "Gets or fetch a user by uri or nickname."
  @spec get_or_fetch(String.t()) :: {:ok, User.t()} | {:error, String.t()}
  def get_or_fetch("http" <> _host = uri), do: get_or_fetch_by_ap_id(uri)
  def get_or_fetch(nickname), do: get_or_fetch_by_nickname(nickname)

  # wait a period of time and return newest version of the User structs
  # this is because we have synchronous follow APIs and need to simulate them
  # with an async handshake
  def wait_and_refresh(_, %User{local: true} = a, %User{local: true} = b) do
    with %User{} = a <- get_cached_by_id(a.id),
         %User{} = b <- get_cached_by_id(b.id) do
      {:ok, a, b}
    else
      nil -> :error
    end
  end

  def wait_and_refresh(timeout, %User{} = a, %User{} = b) do
    with :ok <- :timer.sleep(timeout),
         %User{} = a <- get_cached_by_id(a.id),
         %User{} = b <- get_cached_by_id(b.id) do
      {:ok, a, b}
    else
      nil -> :error
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
    |> Enum.map(&String.downcase/1)
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
    target.ap_id not in user.muted_reblogs
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
      where: u.deactivated != ^true,
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

      iex> Pleroma.User.switch_email_notifications(Pleroma.User{email_notifications: %{"digest" => false}}, "digest", true)
      Pleroma.User{email_notifications: %{"digest" => true}}

      iex> Pleroma.User.switch_email_notifications(Pleroma.User{email_notifications: %{"digest" => true}}, "digest", false)
      Pleroma.User{email_notifications: %{"digest" => false}}
  """
  @spec switch_email_notifications(t(), String.t(), boolean()) ::
          {:ok, t()} | {:error, Ecto.Changeset.t()}
  def switch_email_notifications(user, type, status) do
    User.update_email_notifications(user, %{type => status})
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
    user
    |> confirmation_changeset(need_confirmation: !user.confirmation_pending)
    |> update_and_set_cache()
  end

  def get_mascot(%{mascot: %{} = mascot}) when not is_nil(mascot) do
    mascot
  end

  def get_mascot(%{mascot: mascot}) when is_nil(mascot) do
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

  # A hack because user delete activities have a fake id for whatever reason
  # TODO: Get rid of this
  def get_delivered_users_by_object_id("pleroma:fake_object_id"), do: []

  def get_delivered_users_by_object_id(object_id) do
    from(u in User,
      inner_join: delivery in assoc(u, :deliveries),
      where: delivery.object_id == ^object_id
    )
    |> Repo.all()
  end

  def change_email(user, email) do
    user
    |> cast(%{email: email}, [:email])
    |> validate_required([:email])
    |> unique_constraint(:email)
    |> validate_format(:email, @email_regex)
    |> update_and_set_cache()
  end

  # Internal function; public one is `deactivate/2`
  defp set_activation_status(user, deactivated) do
    user
    |> cast(%{deactivated: deactivated}, [:deactivated])
    |> update_and_set_cache()
  end

  def update_banner(user, banner) do
    user
    |> cast(%{banner: banner}, [:banner])
    |> update_and_set_cache()
  end

  def update_background(user, background) do
    user
    |> cast(%{background: background}, [:background])
    |> update_and_set_cache()
  end

  def update_source_data(user, source_data) do
    user
    |> cast(%{source_data: source_data}, [:source_data])
    |> update_and_set_cache()
  end

  def roles(%{is_moderator: is_moderator, is_admin: is_admin}) do
    %{
      admin: is_admin,
      moderator: is_moderator
    }
  end

  # ``fields`` is an array of mastodon profile field, containing ``{"name": "…", "value": "…"}``.
  # For example: [{"name": "Pronoun", "value": "she/her"}, …]
  def fields(%{fields: nil, source_data: %{"attachment" => attachment}}) do
    limit = Pleroma.Config.get([:instance, :max_remote_account_fields], 0)

    attachment
    |> Enum.filter(fn %{"type" => t} -> t == "PropertyValue" end)
    |> Enum.map(fn fields -> Map.take(fields, ["name", "value"]) end)
    |> Enum.take(limit)
  end

  def fields(%{fields: nil}), do: []

  def fields(%{fields: fields}), do: fields

  def validate_fields(changeset, remote? \\ false) do
    limit_name = if remote?, do: :max_remote_account_fields, else: :max_account_fields
    limit = Pleroma.Config.get([:instance, limit_name], 0)

    changeset
    |> validate_length(:fields, max: limit)
    |> validate_change(:fields, fn :fields, fields ->
      if Enum.all?(fields, &valid_field?/1) do
        []
      else
        [fields: "invalid"]
      end
    end)
  end

  defp valid_field?(%{"name" => name, "value" => value}) do
    name_limit = Pleroma.Config.get([:instance, :account_field_name_length], 255)
    value_limit = Pleroma.Config.get([:instance, :account_field_value_length], 255)

    is_binary(name) && is_binary(value) && String.length(name) <= name_limit &&
      String.length(value) <= value_limit
  end

  defp valid_field?(_), do: false

  defp truncate_field(%{"name" => name, "value" => value}) do
    {name, _chopped} =
      String.split_at(name, Pleroma.Config.get([:instance, :account_field_name_length], 255))

    {value, _chopped} =
      String.split_at(value, Pleroma.Config.get([:instance, :account_field_value_length], 255))

    %{"name" => name, "value" => value}
  end

  def admin_api_update(user, params) do
    user
    |> cast(params, [
      :is_moderator,
      :is_admin,
      :show_role
    ])
    |> update_and_set_cache()
  end

  def mascot_update(user, url) do
    user
    |> cast(%{mascot: url}, [:mascot])
    |> validate_required([:mascot])
    |> update_and_set_cache()
  end

  def mastodon_settings_update(user, settings) do
    user
    |> cast(%{settings: settings}, [:settings])
    |> validate_required([:settings])
    |> update_and_set_cache()
  end

  @spec confirmation_changeset(User.t(), keyword()) :: Changeset.t()
  def confirmation_changeset(user, need_confirmation: need_confirmation?) do
    params =
      if need_confirmation? do
        %{
          confirmation_pending: true,
          confirmation_token: :crypto.strong_rand_bytes(32) |> Base.url_encode64()
        }
      else
        %{
          confirmation_pending: false,
          confirmation_token: nil
        }
      end

    cast(user, params, [:confirmation_pending, :confirmation_token])
  end

  def add_pinnned_activity(user, %Pleroma.Activity{id: id}) do
    if id not in user.pinned_activities do
      max_pinned_statuses = Pleroma.Config.get([:instance, :max_pinned_statuses], 0)
      params = %{pinned_activities: user.pinned_activities ++ [id]}

      user
      |> cast(params, [:pinned_activities])
      |> validate_length(:pinned_activities,
        max: max_pinned_statuses,
        message: "You have already pinned the maximum number of statuses"
      )
    else
      change(user)
    end
    |> update_and_set_cache()
  end

  def remove_pinnned_activity(user, %Pleroma.Activity{id: id}) do
    params = %{pinned_activities: List.delete(user.pinned_activities, id)}

    user
    |> cast(params, [:pinned_activities])
    |> update_and_set_cache()
  end

  def update_email_notifications(user, settings) do
    email_notifications =
      user.email_notifications
      |> Map.merge(settings)
      |> Map.take(["digest"])

    params = %{email_notifications: email_notifications}
    fields = [:email_notifications]

    user
    |> cast(params, fields)
    |> validate_required(fields)
    |> update_and_set_cache()
  end

  defp set_subscribers(user, subscribers) do
    params = %{subscribers: subscribers}

    user
    |> cast(params, [:subscribers])
    |> validate_required([:subscribers])
    |> update_and_set_cache()
  end

  def add_to_subscribers(user, subscribed) do
    set_subscribers(user, Enum.uniq([subscribed | user.subscribers]))
  end

  def remove_from_subscribers(user, subscribed) do
    set_subscribers(user, List.delete(user.subscribers, subscribed))
  end

  defp set_domain_blocks(user, domain_blocks) do
    params = %{domain_blocks: domain_blocks}

    user
    |> cast(params, [:domain_blocks])
    |> validate_required([:domain_blocks])
    |> update_and_set_cache()
  end

  def block_domain(user, domain_blocked) do
    set_domain_blocks(user, Enum.uniq([domain_blocked | user.domain_blocks]))
  end

  def unblock_domain(user, domain_blocked) do
    set_domain_blocks(user, List.delete(user.domain_blocks, domain_blocked))
  end

  defp set_blocks(user, blocks) do
    params = %{blocks: blocks}

    user
    |> cast(params, [:blocks])
    |> validate_required([:blocks])
    |> update_and_set_cache()
  end

  def add_to_block(user, blocked) do
    set_blocks(user, Enum.uniq([blocked | user.blocks]))
  end

  def remove_from_block(user, blocked) do
    set_blocks(user, List.delete(user.blocks, blocked))
  end

  defp set_mutes(user, mutes) do
    params = %{mutes: mutes}

    user
    |> cast(params, [:mutes])
    |> validate_required([:mutes])
    |> update_and_set_cache()
  end

  def add_to_mutes(user, muted, notifications?) do
    with {:ok, user} <- set_mutes(user, Enum.uniq([muted | user.mutes])) do
      set_notification_mutes(
        user,
        Enum.uniq([muted | user.muted_notifications]),
        notifications?
      )
    end
  end

  def remove_from_mutes(user, muted) do
    with {:ok, user} <- set_mutes(user, List.delete(user.mutes, muted)) do
      set_notification_mutes(
        user,
        List.delete(user.muted_notifications, muted),
        true
      )
    end
  end

  defp set_notification_mutes(user, _muted_notifications, false = _notifications?) do
    {:ok, user}
  end

  defp set_notification_mutes(user, muted_notifications, true = _notifications?) do
    params = %{muted_notifications: muted_notifications}

    user
    |> cast(params, [:muted_notifications])
    |> validate_required([:muted_notifications])
    |> update_and_set_cache()
  end

  def add_reblog_mute(user, ap_id) do
    params = %{muted_reblogs: user.muted_reblogs ++ [ap_id]}

    user
    |> cast(params, [:muted_reblogs])
    |> update_and_set_cache()
  end

  def remove_reblog_mute(user, ap_id) do
    params = %{muted_reblogs: List.delete(user.muted_reblogs, ap_id)}

    user
    |> cast(params, [:muted_reblogs])
    |> update_and_set_cache()
  end

  def set_invisible(user, invisible) do
    params = %{invisible: invisible}

    user
    |> cast(params, [:invisible])
    |> validate_required([:invisible])
    |> update_and_set_cache()
  end
end
