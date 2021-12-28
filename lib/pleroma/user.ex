# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query
  import Ecto, only: [assoc: 2]

  alias Ecto.Multi
  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.Conversation.Participation
  alias Pleroma.Delivery
  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Emoji
  alias Pleroma.FollowingRelationship
  alias Pleroma.Formatter
  alias Pleroma.HTML
  alias Pleroma.Keys
  alias Pleroma.MFA
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Registration
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.UserRelationship
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.Pipeline
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils, as: CommonUtils
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.OAuth
  alias Pleroma.Web.RelMe
  alias Pleroma.Workers.BackgroundWorker

  require Logger

  @type t :: %__MODULE__{}
  @type account_status ::
          :active
          | :deactivated
          | :password_reset_pending
          | :confirmation_pending
          | :approval_pending
  @primary_key {:id, FlakeId.Ecto.CompatType, autogenerate: true}

  # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
  @email_regex ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/

  @strict_local_nickname_regex ~r/^[a-zA-Z\d]+$/
  @extended_local_nickname_regex ~r/^[a-zA-Z\d_-]+$/

  # AP ID user relationships (blocks, mutes etc.)
  # Format: [rel_type: [outgoing_rel: :outgoing_rel_target, incoming_rel: :incoming_rel_source]]
  @user_relationships_config [
    block: [
      blocker_blocks: :blocked_users,
      blockee_blocks: :blocker_users
    ],
    mute: [
      muter_mutes: :muted_users,
      mutee_mutes: :muter_users
    ],
    reblog_mute: [
      reblog_muter_mutes: :reblog_muted_users,
      reblog_mutee_mutes: :reblog_muter_users
    ],
    notification_mute: [
      notification_muter_mutes: :notification_muted_users,
      notification_mutee_mutes: :notification_muter_users
    ],
    # Note: `inverse_subscription` relationship is inverse: subscriber acts as relationship target
    inverse_subscription: [
      subscribee_subscriptions: :subscriber_users,
      subscriber_subscriptions: :subscribee_users
    ]
  ]

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

  schema "users" do
    field(:bio, :string, default: "")
    field(:raw_bio, :string)
    field(:email, :string)
    field(:name, :string)
    field(:nickname, :string)
    field(:password_hash, :string)
    field(:password, :string, virtual: true)
    field(:password_confirmation, :string, virtual: true)
    field(:keys, :string)
    field(:public_key, :string)
    field(:ap_id, :string)
    field(:avatar, :map, default: %{})
    field(:local, :boolean, default: true)
    field(:follower_address, :string)
    field(:following_address, :string)
    field(:featured_address, :string)
    field(:search_rank, :float, virtual: true)
    field(:search_type, :integer, virtual: true)
    field(:tags, {:array, :string}, default: [])
    field(:last_refreshed_at, :naive_datetime_usec)
    field(:last_digest_emailed_at, :naive_datetime)
    field(:banner, :map, default: %{})
    field(:background, :map, default: %{})
    field(:note_count, :integer, default: 0)
    field(:follower_count, :integer, default: 0)
    field(:following_count, :integer, default: 0)
    field(:is_locked, :boolean, default: false)
    field(:is_confirmed, :boolean, default: true)
    field(:password_reset_pending, :boolean, default: false)
    field(:is_approved, :boolean, default: true)
    field(:registration_reason, :string, default: nil)
    field(:confirmation_token, :string, default: nil)
    field(:default_scope, :string, default: "public")
    field(:domain_blocks, {:array, :string}, default: [])
    field(:is_active, :boolean, default: true)
    field(:no_rich_text, :boolean, default: false)
    field(:ap_enabled, :boolean, default: false)
    field(:is_moderator, :boolean, default: false)
    field(:is_admin, :boolean, default: false)
    field(:show_role, :boolean, default: true)
    field(:uri, ObjectValidators.Uri, default: nil)
    field(:hide_followers_count, :boolean, default: false)
    field(:hide_follows_count, :boolean, default: false)
    field(:hide_followers, :boolean, default: false)
    field(:hide_follows, :boolean, default: false)
    field(:hide_favorites, :boolean, default: true)
    field(:email_notifications, :map, default: %{"digest" => false})
    field(:mascot, :map, default: nil)
    field(:emoji, :map, default: %{})
    field(:pleroma_settings_store, :map, default: %{})
    field(:fields, {:array, :map}, default: [])
    field(:raw_fields, {:array, :map}, default: [])
    field(:is_discoverable, :boolean, default: false)
    field(:invisible, :boolean, default: false)
    field(:allow_following_move, :boolean, default: true)
    field(:skip_thread_containment, :boolean, default: false)
    field(:actor_type, :string, default: "Person")
    field(:also_known_as, {:array, ObjectValidators.ObjectID}, default: [])
    field(:inbox, :string)
    field(:shared_inbox, :string)
    field(:accepts_chat_messages, :boolean, default: nil)
    field(:last_active_at, :naive_datetime)
    field(:disclose_client, :boolean, default: true)
    field(:pinned_objects, :map, default: %{})
    field(:is_suggested, :boolean, default: false)
    field(:last_status_at, :naive_datetime)

    embeds_one(
      :notification_settings,
      Pleroma.User.NotificationSetting,
      on_replace: :update
    )

    has_many(:notifications, Notification)
    has_many(:registrations, Registration)
    has_many(:deliveries, Delivery)

    has_many(:outgoing_relationships, UserRelationship, foreign_key: :source_id)
    has_many(:incoming_relationships, UserRelationship, foreign_key: :target_id)

    for {relationship_type,
         [
           {outgoing_relation, outgoing_relation_target},
           {incoming_relation, incoming_relation_source}
         ]} <- @user_relationships_config do
      # Definitions of `has_many` relations: :blocker_blocks, :muter_mutes, :reblog_muter_mutes,
      #   :notification_muter_mutes, :subscribee_subscriptions
      has_many(outgoing_relation, UserRelationship,
        foreign_key: :source_id,
        where: [relationship_type: relationship_type]
      )

      # Definitions of `has_many` relations: :blockee_blocks, :mutee_mutes, :reblog_mutee_mutes,
      #   :notification_mutee_mutes, :subscriber_subscriptions
      has_many(incoming_relation, UserRelationship,
        foreign_key: :target_id,
        where: [relationship_type: relationship_type]
      )

      # Definitions of `has_many` relations: :blocked_users, :muted_users, :reblog_muted_users,
      #   :notification_muted_users, :subscriber_users
      has_many(outgoing_relation_target, through: [outgoing_relation, :target])

      # Definitions of `has_many` relations: :blocker_users, :muter_users, :reblog_muter_users,
      #   :notification_muter_users, :subscribee_users
      has_many(incoming_relation_source, through: [incoming_relation, :source])
    end

    # `:blocks` is deprecated (replaced with `blocked_users` relation)
    field(:blocks, {:array, :string}, default: [])
    # `:mutes` is deprecated (replaced with `muted_users` relation)
    field(:mutes, {:array, :string}, default: [])
    # `:muted_reblogs` is deprecated (replaced with `reblog_muted_users` relation)
    field(:muted_reblogs, {:array, :string}, default: [])
    # `:muted_notifications` is deprecated (replaced with `notification_muted_users` relation)
    field(:muted_notifications, {:array, :string}, default: [])
    # `:subscribers` is deprecated (replaced with `subscriber_users` relation)
    field(:subscribers, {:array, :string}, default: [])

    embeds_one(
      :multi_factor_authentication_settings,
      MFA.Settings,
      on_replace: :delete
    )

    timestamps()
  end

  for {_relationship_type, [{_outgoing_relation, outgoing_relation_target}, _]} <-
        @user_relationships_config do
    # `def blocked_users_relation/2`, `def muted_users_relation/2`,
    #   `def reblog_muted_users_relation/2`, `def notification_muted_users/2`,
    #   `def subscriber_users/2`
    def unquote(:"#{outgoing_relation_target}_relation")(user, restrict_deactivated? \\ false) do
      target_users_query = assoc(user, unquote(outgoing_relation_target))

      if restrict_deactivated? do
        target_users_query
        |> User.Query.build(%{deactivated: false})
      else
        target_users_query
      end
    end

    # `def blocked_users/2`, `def muted_users/2`, `def reblog_muted_users/2`,
    #   `def notification_muted_users/2`, `def subscriber_users/2`
    def unquote(outgoing_relation_target)(user, restrict_deactivated? \\ false) do
      __MODULE__
      |> apply(unquote(:"#{outgoing_relation_target}_relation"), [
        user,
        restrict_deactivated?
      ])
      |> Repo.all()
    end

    # `def blocked_users_ap_ids/2`, `def muted_users_ap_ids/2`, `def reblog_muted_users_ap_ids/2`,
    #   `def notification_muted_users_ap_ids/2`, `def subscriber_users_ap_ids/2`
    def unquote(:"#{outgoing_relation_target}_ap_ids")(user, restrict_deactivated? \\ false) do
      __MODULE__
      |> apply(unquote(:"#{outgoing_relation_target}_relation"), [
        user,
        restrict_deactivated?
      ])
      |> select([u], u.ap_id)
      |> Repo.all()
    end
  end

  def cached_blocked_users_ap_ids(user) do
    @cachex.fetch!(:user_cache, "blocked_users_ap_ids:#{user.ap_id}", fn _ ->
      blocked_users_ap_ids(user)
    end)
  end

  def cached_muted_users_ap_ids(user) do
    @cachex.fetch!(:user_cache, "muted_users_ap_ids:#{user.ap_id}", fn _ ->
      muted_users_ap_ids(user)
    end)
  end

  defdelegate following_count(user), to: FollowingRelationship
  defdelegate following(user), to: FollowingRelationship
  defdelegate following?(follower, followed), to: FollowingRelationship
  defdelegate following_ap_ids(user), to: FollowingRelationship
  defdelegate get_follow_requests(user), to: FollowingRelationship
  defdelegate search(query, opts \\ []), to: User.Search

  @doc """
  Dumps Flake Id to SQL-compatible format (16-byte UUID).
  E.g. "9pQtDGXuq4p3VlcJEm" -> <<0, 0, 1, 110, 179, 218, 42, 92, 213, 41, 44, 227, 95, 213, 0, 0>>
  """
  def binary_id(source_id) when is_binary(source_id) do
    with {:ok, dumped_id} <- FlakeId.Ecto.CompatType.dump(source_id) do
      dumped_id
    else
      _ -> source_id
    end
  end

  def binary_id(source_ids) when is_list(source_ids) do
    Enum.map(source_ids, &binary_id/1)
  end

  def binary_id(%User{} = user), do: binary_id(user.id)

  @doc "Returns status account"
  @spec account_status(User.t()) :: account_status()
  def account_status(%User{is_active: false}), do: :deactivated
  def account_status(%User{password_reset_pending: true}), do: :password_reset_pending
  def account_status(%User{local: true, is_approved: false}), do: :approval_pending
  def account_status(%User{local: true, is_confirmed: false}), do: :confirmation_pending
  def account_status(%User{}), do: :active

  @spec visible_for(User.t(), User.t() | nil) ::
          :visible
          | :invisible
          | :restricted_unauthenticated
          | :deactivated
          | :confirmation_pending
  def visible_for(user, for_user \\ nil)

  def visible_for(%User{invisible: true}, _), do: :invisible

  def visible_for(%User{id: user_id}, %User{id: user_id}), do: :visible

  def visible_for(%User{} = user, nil) do
    if restrict_unauthenticated?(user) do
      :restrict_unauthenticated
    else
      visible_account_status(user)
    end
  end

  def visible_for(%User{} = user, for_user) do
    if superuser?(for_user) do
      :visible
    else
      visible_account_status(user)
    end
  end

  def visible_for(_, _), do: :invisible

  defp restrict_unauthenticated?(%User{local: true}) do
    Config.restrict_unauthenticated_access?(:profiles, :local)
  end

  defp restrict_unauthenticated?(%User{local: _}) do
    Config.restrict_unauthenticated_access?(:profiles, :remote)
  end

  defp visible_account_status(user) do
    status = account_status(user)

    if status in [:active, :password_reset_pending] do
      :visible
    else
      status
    end
  end

  @spec superuser?(User.t()) :: boolean()
  def superuser?(%User{local: true, is_admin: true}), do: true
  def superuser?(%User{local: true, is_moderator: true}), do: true
  def superuser?(_), do: false

  @spec invisible?(User.t()) :: boolean()
  def invisible?(%User{invisible: true}), do: true
  def invisible?(_), do: false

  def avatar_url(user, options \\ []) do
    case user.avatar do
      %{"url" => [%{"href" => href} | _]} ->
        href

      _ ->
        unless options[:no_default] do
          Config.get([:assets, :default_user_avatar], "#{Endpoint.url()}/images/avi.png")
        end
    end
  end

  def banner_url(user, options \\ []) do
    case user.banner do
      %{"url" => [%{"href" => href} | _]} -> href
      _ -> !options[:no_default] && "#{Endpoint.url()}/images/banner.png"
    end
  end

  # Should probably be renamed or removed
  @spec ap_id(User.t()) :: String.t()
  def ap_id(%User{nickname: nickname}), do: "#{Endpoint.url()}/users/#{nickname}"

  @spec ap_followers(User.t()) :: String.t()
  def ap_followers(%User{follower_address: fa}) when is_binary(fa), do: fa
  def ap_followers(%User{} = user), do: "#{ap_id(user)}/followers"

  @spec ap_following(User.t()) :: String.t()
  def ap_following(%User{following_address: fa}) when is_binary(fa), do: fa
  def ap_following(%User{} = user), do: "#{ap_id(user)}/following"

  @spec ap_featured_collection(User.t()) :: String.t()
  def ap_featured_collection(%User{featured_address: fa}) when is_binary(fa), do: fa

  def ap_featured_collection(%User{} = user), do: "#{ap_id(user)}/collections/featured"

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

  defp fix_follower_address(%{follower_address: _, following_address: _} = params), do: params

  defp fix_follower_address(%{nickname: nickname} = params),
    do: Map.put(params, :follower_address, ap_followers(%User{nickname: nickname}))

  defp fix_follower_address(params), do: params

  def remote_user_changeset(struct \\ %User{local: false}, params) do
    bio_limit = Config.get([:instance, :user_bio_length], 5000)
    name_limit = Config.get([:instance, :user_name_length], 100)

    name =
      case params[:name] do
        name when is_binary(name) and byte_size(name) > 0 -> name
        _ -> params[:nickname]
      end

    params =
      params
      |> Map.put(:name, name)
      |> Map.put_new(:last_refreshed_at, NaiveDateTime.utc_now())
      |> truncate_if_exists(:name, name_limit)
      |> truncate_if_exists(:bio, bio_limit)
      |> truncate_fields_param()
      |> fix_follower_address()

    struct
    |> cast(
      params,
      [
        :bio,
        :emoji,
        :ap_id,
        :inbox,
        :shared_inbox,
        :nickname,
        :public_key,
        :avatar,
        :ap_enabled,
        :banner,
        :is_locked,
        :last_refreshed_at,
        :uri,
        :follower_address,
        :following_address,
        :featured_address,
        :hide_followers,
        :hide_follows,
        :hide_followers_count,
        :hide_follows_count,
        :follower_count,
        :fields,
        :following_count,
        :is_discoverable,
        :invisible,
        :actor_type,
        :also_known_as,
        :accepts_chat_messages,
        :pinned_objects
      ]
    )
    |> cast(params, [:name], empty_values: [])
    |> validate_required([:ap_id])
    |> validate_required([:name], trim: false)
    |> unique_constraint(:nickname)
    |> validate_format(:nickname, @email_regex)
    |> validate_length(:bio, max: bio_limit)
    |> validate_length(:name, max: name_limit)
    |> validate_fields(true)
    |> validate_non_local()
  end

  defp validate_non_local(cng) do
    local? = get_field(cng, :local)

    if local? do
      cng
      |> add_error(:local, "User is local, can't update with this changeset.")
    else
      cng
    end
  end

  def update_changeset(struct, params \\ %{}) do
    bio_limit = Config.get([:instance, :user_bio_length], 5000)
    name_limit = Config.get([:instance, :user_name_length], 100)

    struct
    |> cast(
      params,
      [
        :bio,
        :raw_bio,
        :name,
        :emoji,
        :avatar,
        :public_key,
        :inbox,
        :shared_inbox,
        :is_locked,
        :no_rich_text,
        :default_scope,
        :banner,
        :hide_follows,
        :hide_followers,
        :hide_followers_count,
        :hide_follows_count,
        :hide_favorites,
        :allow_following_move,
        :also_known_as,
        :background,
        :show_role,
        :skip_thread_containment,
        :fields,
        :raw_fields,
        :pleroma_settings_store,
        :is_discoverable,
        :actor_type,
        :accepts_chat_messages,
        :disclose_client
      ]
    )
    |> unique_constraint(:nickname)
    |> validate_format(:nickname, local_nickname_regex())
    |> validate_length(:bio, max: bio_limit)
    |> validate_length(:name, min: 1, max: name_limit)
    |> validate_inclusion(:actor_type, ["Person", "Service"])
    |> put_fields()
    |> put_emoji()
    |> put_change_if_present(:bio, &{:ok, parse_bio(&1, struct)})
    |> put_change_if_present(:avatar, &put_upload(&1, :avatar))
    |> put_change_if_present(:banner, &put_upload(&1, :banner))
    |> put_change_if_present(:background, &put_upload(&1, :background))
    |> put_change_if_present(
      :pleroma_settings_store,
      &{:ok, Map.merge(struct.pleroma_settings_store, &1)}
    )
    |> validate_fields(false)
  end

  defp put_fields(changeset) do
    if raw_fields = get_change(changeset, :raw_fields) do
      raw_fields =
        raw_fields
        |> Enum.filter(fn %{"name" => n} -> n != "" end)

      fields =
        raw_fields
        |> Enum.map(fn f -> Map.update!(f, "value", &parse_fields(&1)) end)

      changeset
      |> put_change(:raw_fields, raw_fields)
      |> put_change(:fields, fields)
    else
      changeset
    end
  end

  defp parse_fields(value) do
    value
    |> Formatter.linkify(mentions_format: :full)
    |> elem(0)
  end

  defp put_emoji(changeset) do
    emojified_fields = [:bio, :name, :raw_fields]

    if Enum.any?(changeset.changes, fn {k, _} -> k in emojified_fields end) do
      bio = Emoji.Formatter.get_emoji_map(get_field(changeset, :bio))
      name = Emoji.Formatter.get_emoji_map(get_field(changeset, :name))

      emoji = Map.merge(bio, name)

      emoji =
        changeset
        |> get_field(:raw_fields)
        |> Enum.reduce(emoji, fn x, acc ->
          Map.merge(acc, Emoji.Formatter.get_emoji_map(x["name"] <> x["value"]))
        end)

      put_change(changeset, :emoji, emoji)
    else
      changeset
    end
  end

  defp put_change_if_present(changeset, map_field, value_function) do
    with {:ok, value} <- fetch_change(changeset, map_field),
         {:ok, new_value} <- value_function.(value) do
      put_change(changeset, map_field, new_value)
    else
      _ -> changeset
    end
  end

  defp put_upload(value, type) do
    with %Plug.Upload{} <- value,
         {:ok, object} <- ActivityPub.upload(value, type: type) do
      {:ok, object.data}
    end
  end

  def update_as_admin_changeset(struct, params) do
    struct
    |> update_changeset(params)
    |> cast(params, [:email])
    |> delete_change(:also_known_as)
    |> unique_constraint(:email)
    |> validate_format(:email, @email_regex)
    |> validate_inclusion(:actor_type, ["Person", "Service"])
  end

  @spec update_as_admin(User.t(), map()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def update_as_admin(user, params) do
    params = Map.put(params, "password_confirmation", params["password"])
    changeset = update_as_admin_changeset(user, params)

    if params["password"] do
      reset_password(user, changeset, params)
    else
      User.update_and_set_cache(changeset)
    end
  end

  def password_update_changeset(struct, params) do
    struct
    |> cast(params, [:password, :password_confirmation])
    |> validate_required([:password, :password_confirmation])
    |> validate_confirmation(:password)
    |> put_password_hash()
    |> put_change(:password_reset_pending, false)
  end

  @spec reset_password(User.t(), map()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def reset_password(%User{} = user, params) do
    reset_password(user, user, params)
  end

  def reset_password(%User{id: user_id} = user, struct, params) do
    multi =
      Multi.new()
      |> Multi.update(:user, password_update_changeset(struct, params))
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

  # Used to auto-register LDAP accounts which won't have a password hash stored locally
  def register_changeset_ldap(struct, params = %{password: password})
      when is_nil(password) do
    params = Map.put_new(params, :accepts_chat_messages, true)

    params =
      if Map.has_key?(params, :email) do
        Map.put_new(params, :email, params[:email])
      else
        params
      end

    struct
    |> cast(params, [
      :name,
      :nickname,
      :email,
      :accepts_chat_messages
    ])
    |> validate_required([:name, :nickname])
    |> unique_constraint(:nickname)
    |> validate_exclusion(:nickname, Config.get([User, :restricted_nicknames]))
    |> validate_format(:nickname, local_nickname_regex())
    |> put_ap_id()
    |> unique_constraint(:ap_id)
    |> put_following_and_follower_and_featured_address()
  end

  def register_changeset(struct, params \\ %{}, opts \\ []) do
    bio_limit = Config.get([:instance, :user_bio_length], 5000)
    name_limit = Config.get([:instance, :user_name_length], 100)
    reason_limit = Config.get([:instance, :registration_reason_length], 500)
    params = Map.put_new(params, :accepts_chat_messages, true)

    confirmed? =
      if is_nil(opts[:confirmed]) do
        !Config.get([:instance, :account_activation_required])
      else
        opts[:confirmed]
      end

    approved? =
      if is_nil(opts[:approved]) do
        !Config.get([:instance, :account_approval_required])
      else
        opts[:approved]
      end

    struct
    |> confirmation_changeset(set_confirmation: confirmed?)
    |> approval_changeset(set_approval: approved?)
    |> cast(params, [
      :bio,
      :raw_bio,
      :email,
      :name,
      :nickname,
      :password,
      :password_confirmation,
      :emoji,
      :accepts_chat_messages,
      :registration_reason
    ])
    |> validate_required([:name, :nickname, :password, :password_confirmation])
    |> validate_confirmation(:password)
    |> unique_constraint(:email)
    |> validate_format(:email, @email_regex)
    |> validate_change(:email, fn :email, email ->
      valid? =
        Config.get([User, :email_blacklist])
        |> Enum.all?(fn blacklisted_domain ->
          !String.ends_with?(email, ["@" <> blacklisted_domain, "." <> blacklisted_domain])
        end)

      if valid?, do: [], else: [email: "Invalid email"]
    end)
    |> unique_constraint(:nickname)
    |> validate_exclusion(:nickname, Config.get([User, :restricted_nicknames]))
    |> validate_format(:nickname, local_nickname_regex())
    |> validate_length(:bio, max: bio_limit)
    |> validate_length(:name, min: 1, max: name_limit)
    |> validate_length(:registration_reason, max: reason_limit)
    |> maybe_validate_required_email(opts[:external])
    |> put_password_hash
    |> put_ap_id()
    |> unique_constraint(:ap_id)
    |> put_following_and_follower_and_featured_address()
  end

  def maybe_validate_required_email(changeset, true), do: changeset

  def maybe_validate_required_email(changeset, _) do
    if Config.get([:instance, :account_activation_required]) do
      validate_required(changeset, [:email])
    else
      changeset
    end
  end

  defp put_ap_id(changeset) do
    ap_id = ap_id(%User{nickname: get_field(changeset, :nickname)})
    put_change(changeset, :ap_id, ap_id)
  end

  defp put_following_and_follower_and_featured_address(changeset) do
    user = %User{nickname: get_field(changeset, :nickname)}
    followers = ap_followers(user)
    following = ap_following(user)
    featured = ap_featured_collection(user)

    changeset
    |> put_change(:follower_address, followers)
    |> put_change(:following_address, following)
    |> put_change(:featured_address, featured)
  end

  defp autofollow_users(user) do
    candidates = Config.get([:instance, :autofollowed_nicknames])

    autofollowed_users =
      User.Query.build(%{nickname: candidates, local: true, is_active: true})
      |> Repo.all()

    follow_all(user, autofollowed_users)
  end

  defp autofollowing_users(user) do
    candidates = Config.get([:instance, :autofollowing_nicknames])

    User.Query.build(%{nickname: candidates, local: true, deactivated: false})
    |> Repo.all()
    |> Enum.each(&follow(&1, user, :follow_accept))

    {:ok, :success}
  end

  @doc "Inserts provided changeset, performs post-registration actions (confirmation email sending etc.)"
  def register(%Ecto.Changeset{} = changeset) do
    with {:ok, user} <- Repo.insert(changeset) do
      post_register_action(user)
    end
  end

  def post_register_action(%User{is_confirmed: false} = user) do
    with {:ok, _} <- maybe_send_confirmation_email(user) do
      {:ok, user}
    end
  end

  def post_register_action(%User{is_approved: false} = user) do
    with {:ok, _} <- send_user_approval_email(user),
         {:ok, _} <- send_admin_approval_emails(user) do
      {:ok, user}
    end
  end

  def post_register_action(%User{is_approved: true, is_confirmed: true} = user) do
    with {:ok, user} <- autofollow_users(user),
         {:ok, _} <- autofollowing_users(user),
         {:ok, user} <- set_cache(user),
         {:ok, _} <- maybe_send_registration_email(user),
         {:ok, _} <- maybe_send_welcome_email(user),
         {:ok, _} <- maybe_send_welcome_message(user),
         {:ok, _} <- maybe_send_welcome_chat_message(user) do
      {:ok, user}
    end
  end

  defp send_user_approval_email(user) do
    user
    |> Pleroma.Emails.UserEmail.approval_pending_email()
    |> Pleroma.Emails.Mailer.deliver_async()

    {:ok, :enqueued}
  end

  defp send_admin_approval_emails(user) do
    all_superusers()
    |> Enum.filter(fn user -> not is_nil(user.email) end)
    |> Enum.each(fn superuser ->
      superuser
      |> Pleroma.Emails.AdminEmail.new_unapproved_registration(user)
      |> Pleroma.Emails.Mailer.deliver_async()
    end)

    {:ok, :enqueued}
  end

  defp maybe_send_welcome_message(user) do
    if User.WelcomeMessage.enabled?() do
      User.WelcomeMessage.post_message(user)
      {:ok, :enqueued}
    else
      {:ok, :noop}
    end
  end

  defp maybe_send_welcome_chat_message(user) do
    if User.WelcomeChatMessage.enabled?() do
      User.WelcomeChatMessage.post_message(user)
      {:ok, :enqueued}
    else
      {:ok, :noop}
    end
  end

  defp maybe_send_welcome_email(%User{email: email} = user) when is_binary(email) do
    if User.WelcomeEmail.enabled?() do
      User.WelcomeEmail.send_email(user)
      {:ok, :enqueued}
    else
      {:ok, :noop}
    end
  end

  defp maybe_send_welcome_email(_), do: {:ok, :noop}

  @spec maybe_send_confirmation_email(User.t()) :: {:ok, :enqueued | :noop}
  def maybe_send_confirmation_email(%User{is_confirmed: false, email: email} = user)
      when is_binary(email) do
    if Config.get([:instance, :account_activation_required]) do
      send_confirmation_email(user)
      {:ok, :enqueued}
    else
      {:ok, :noop}
    end
  end

  def maybe_send_confirmation_email(_), do: {:ok, :noop}

  @spec send_confirmation_email(Uset.t()) :: User.t()
  def send_confirmation_email(%User{} = user) do
    user
    |> Pleroma.Emails.UserEmail.account_confirmation_email()
    |> Pleroma.Emails.Mailer.deliver_async()

    user
  end

  @spec maybe_send_registration_email(User.t()) :: {:ok, :enqueued | :noop}
  defp maybe_send_registration_email(%User{email: email} = user) when is_binary(email) do
    with false <- User.WelcomeEmail.enabled?(),
         false <- Config.get([:instance, :account_activation_required], false),
         false <- Config.get([:instance, :account_approval_required], false) do
      user
      |> Pleroma.Emails.UserEmail.successful_registration_email()
      |> Pleroma.Emails.Mailer.deliver_async()

      {:ok, :enqueued}
    else
      _ ->
        {:ok, :noop}
    end
  end

  defp maybe_send_registration_email(_), do: {:ok, :noop}

  def needs_update?(%User{local: true}), do: false

  def needs_update?(%User{local: false, last_refreshed_at: nil}), do: true

  def needs_update?(%User{local: false} = user) do
    NaiveDateTime.diff(NaiveDateTime.utc_now(), user.last_refreshed_at) >= 86_400
  end

  def needs_update?(_), do: true

  @spec maybe_direct_follow(User.t(), User.t()) :: {:ok, User.t()} | {:error, String.t()}

  # "Locked" (self-locked) users demand explicit authorization of follow requests
  def maybe_direct_follow(%User{} = follower, %User{local: true, is_locked: true} = followed) do
    follow(follower, followed, :follow_pending)
  end

  def maybe_direct_follow(%User{} = follower, %User{local: true} = followed) do
    follow(follower, followed)
  end

  def maybe_direct_follow(%User{} = follower, %User{} = followed) do
    if not ap_enabled?(followed) do
      follow(follower, followed)
    else
      {:ok, follower, followed}
    end
  end

  @doc "A mass follow for local users. Respects blocks in both directions but does not create activities."
  @spec follow_all(User.t(), list(User.t())) :: {atom(), User.t()}
  def follow_all(follower, followeds) do
    followeds
    |> Enum.reject(fn followed -> blocks?(follower, followed) || blocks?(followed, follower) end)
    |> Enum.each(&follow(follower, &1, :follow_accept))

    set_cache(follower)
  end

  def follow(%User{} = follower, %User{} = followed, state \\ :follow_accept) do
    deny_follow_blocked = Config.get([:user, :deny_follow_blocked])

    cond do
      not followed.is_active ->
        {:error, "Could not follow user: #{followed.nickname} is deactivated."}

      deny_follow_blocked and blocks?(followed, follower) ->
        {:error, "Could not follow user: #{followed.nickname} blocked you."}

      true ->
        FollowingRelationship.follow(follower, followed, state)
    end
  end

  def unfollow(%User{ap_id: ap_id}, %User{ap_id: ap_id}) do
    {:error, "Not subscribed!"}
  end

  @spec unfollow(User.t(), User.t()) :: {:ok, User.t(), Activity.t()} | {:error, String.t()}
  def unfollow(%User{} = follower, %User{} = followed) do
    case do_unfollow(follower, followed) do
      {:ok, follower, followed} ->
        {:ok, follower, Utils.fetch_latest_follow(follower, followed)}

      error ->
        error
    end
  end

  @spec do_unfollow(User.t(), User.t()) :: {:ok, User.t(), User.t()} | {:error, String.t()}
  defp do_unfollow(%User{} = follower, %User{} = followed) do
    case get_follow_state(follower, followed) do
      state when state in [:follow_pending, :follow_accept] ->
        FollowingRelationship.unfollow(follower, followed)

      nil ->
        {:error, "Not subscribed!"}
    end
  end

  @doc "Returns follow state as Pleroma.FollowingRelationship.State value"
  def get_follow_state(%User{} = follower, %User{} = following) do
    following_relationship = FollowingRelationship.get(follower, following)
    get_follow_state(follower, following, following_relationship)
  end

  def get_follow_state(
        %User{} = follower,
        %User{} = following,
        following_relationship
      ) do
    case {following_relationship, following.local} do
      {nil, false} ->
        case Utils.fetch_latest_follow(follower, following) do
          %Activity{data: %{"state" => state}} when state in ["pending", "accept"] ->
            FollowingRelationship.state_to_enum(state)

          _ ->
            nil
        end

      {%{state: state}, _} ->
        state

      {nil, _} ->
        nil
    end
  end

  def locked?(%User{} = user) do
    user.is_locked || false
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
    @cachex.put(:user_cache, "ap_id:#{user.ap_id}", user)
    @cachex.put(:user_cache, "nickname:#{user.nickname}", user)
    @cachex.put(:user_cache, "friends_ap_ids:#{user.nickname}", get_user_friends_ap_ids(user))
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

  def get_user_friends_ap_ids(user) do
    from(u in User.get_friends_query(user), select: u.ap_id)
    |> Repo.all()
  end

  @spec get_cached_user_friends_ap_ids(User.t()) :: [String.t()]
  def get_cached_user_friends_ap_ids(user) do
    @cachex.fetch!(:user_cache, "friends_ap_ids:#{user.ap_id}", fn _ ->
      get_user_friends_ap_ids(user)
    end)
  end

  def invalidate_cache(user) do
    @cachex.del(:user_cache, "ap_id:#{user.ap_id}")
    @cachex.del(:user_cache, "nickname:#{user.nickname}")
    @cachex.del(:user_cache, "friends_ap_ids:#{user.ap_id}")
    @cachex.del(:user_cache, "blocked_users_ap_ids:#{user.ap_id}")
    @cachex.del(:user_cache, "muted_users_ap_ids:#{user.ap_id}")
  end

  @spec get_cached_by_ap_id(String.t()) :: User.t() | nil
  def get_cached_by_ap_id(ap_id) do
    key = "ap_id:#{ap_id}"

    with {:ok, nil} <- @cachex.get(:user_cache, key),
         user when not is_nil(user) <- get_by_ap_id(ap_id),
         {:ok, true} <- @cachex.put(:user_cache, key, user) do
      user
    else
      {:ok, user} -> user
      nil -> nil
    end
  end

  def get_cached_by_id(id) do
    key = "id:#{id}"

    ap_id =
      @cachex.fetch!(:user_cache, key, fn _ ->
        user = get_by_id(id)

        if user do
          @cachex.put(:user_cache, "ap_id:#{user.ap_id}", user)
          {:commit, user.ap_id}
        else
          {:ignore, ""}
        end
      end)

    get_cached_by_ap_id(ap_id)
  end

  def get_cached_by_nickname(nickname) do
    key = "nickname:#{nickname}"

    @cachex.fetch!(:user_cache, key, fn _ ->
      case get_or_fetch_by_nickname(nickname) do
        {:ok, user} -> {:commit, user}
        {:error, _error} -> {:ignore, nil}
      end
    end)
  end

  def get_cached_by_nickname_or_id(nickname_or_id, opts \\ []) do
    restrict_to_local = Config.get([:instance, :limit_to_local_content])

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

  @spec get_by_nickname(String.t()) :: User.t() | nil
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

  def fetch_by_nickname(nickname), do: ActivityPub.make_user_from_nickname(nickname)

  def get_or_fetch_by_nickname(nickname) do
    with %User{} = user <- get_by_nickname(nickname) do
      {:ok, user}
    else
      _e ->
        with [_nick, _domain] <- String.split(nickname, "@"),
             {:ok, user} <- fetch_by_nickname(nickname) do
          {:ok, user}
        else
          _e -> {:error, "not found " <> nickname}
        end
    end
  end

  @spec get_followers_query(User.t(), pos_integer() | nil) :: Ecto.Query.t()
  def get_followers_query(%User{} = user, nil) do
    User.Query.build(%{followers: user, is_active: true})
  end

  def get_followers_query(%User{} = user, page) do
    user
    |> get_followers_query(nil)
    |> User.Query.paginate(page, 20)
  end

  @spec get_followers_query(User.t()) :: Ecto.Query.t()
  def get_followers_query(%User{} = user), do: get_followers_query(user, nil)

  @spec get_followers(User.t(), pos_integer() | nil) :: {:ok, list(User.t())}
  def get_followers(%User{} = user, page \\ nil) do
    user
    |> get_followers_query(page)
    |> Repo.all()
  end

  @spec get_external_followers(User.t(), pos_integer() | nil) :: {:ok, list(User.t())}
  def get_external_followers(%User{} = user, page \\ nil) do
    user
    |> get_followers_query(page)
    |> User.Query.build(%{external: true})
    |> Repo.all()
  end

  def get_followers_ids(%User{} = user, page \\ nil) do
    user
    |> get_followers_query(page)
    |> select([u], u.id)
    |> Repo.all()
  end

  @spec get_friends_query(User.t(), pos_integer() | nil) :: Ecto.Query.t()
  def get_friends_query(%User{} = user, nil) do
    User.Query.build(%{friends: user, deactivated: false})
  end

  def get_friends_query(%User{} = user, page) do
    user
    |> get_friends_query(nil)
    |> User.Query.paginate(page, 20)
  end

  @spec get_friends_query(User.t()) :: Ecto.Query.t()
  def get_friends_query(%User{} = user), do: get_friends_query(user, nil)

  def get_friends(%User{} = user, page \\ nil) do
    user
    |> get_friends_query(page)
    |> Repo.all()
  end

  def get_friends_ap_ids(%User{} = user) do
    user
    |> get_friends_query(nil)
    |> select([u], u.ap_id)
    |> Repo.all()
  end

  def get_friends_ids(%User{} = user, page \\ nil) do
    user
    |> get_friends_query(page)
    |> select([u], u.id)
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

  @spec update_follower_count(User.t()) :: {:ok, User.t()}
  def update_follower_count(%User{} = user) do
    if user.local or !Config.get([:instance, :external_user_synchronization]) do
      follower_count = FollowingRelationship.follower_count(user)

      user
      |> follow_information_changeset(%{follower_count: follower_count})
      |> update_and_set_cache
    else
      {:ok, maybe_fetch_follow_information(user)}
    end
  end

  @spec update_following_count(User.t()) :: {:ok, User.t()}
  def update_following_count(%User{local: false} = user) do
    if Config.get([:instance, :external_user_synchronization]) do
      {:ok, maybe_fetch_follow_information(user)}
    else
      {:ok, user}
    end
  end

  def update_following_count(%User{local: true} = user) do
    following_count = FollowingRelationship.following_count(user)

    user
    |> follow_information_changeset(%{following_count: following_count})
    |> update_and_set_cache()
  end

  @spec get_users_from_set([String.t()], keyword()) :: [User.t()]
  def get_users_from_set(ap_ids, opts \\ []) do
    local_only = Keyword.get(opts, :local_only, true)
    criteria = %{ap_id: ap_ids, is_active: true}
    criteria = if local_only, do: Map.put(criteria, :local, true), else: criteria

    User.Query.build(criteria)
    |> Repo.all()
  end

  @spec get_recipients_from_activity(Activity.t()) :: [User.t()]
  def get_recipients_from_activity(%Activity{recipients: to, actor: actor}) do
    to = [actor | to]

    query = User.Query.build(%{recipients_from_activity: to, local: true, is_active: true})

    query
    |> Repo.all()
  end

  @spec mute(User.t(), User.t(), map()) ::
          {:ok, list(UserRelationship.t())} | {:error, String.t()}
  def mute(%User{} = muter, %User{} = mutee, params \\ %{}) do
    notifications? = Map.get(params, :notifications, true)
    expires_in = Map.get(params, :expires_in, 0)

    with {:ok, user_mute} <- UserRelationship.create_mute(muter, mutee),
         {:ok, user_notification_mute} <-
           (notifications? && UserRelationship.create_notification_mute(muter, mutee)) ||
             {:ok, nil} do
      if expires_in > 0 do
        Pleroma.Workers.MuteExpireWorker.enqueue(
          "unmute_user",
          %{"muter_id" => muter.id, "mutee_id" => mutee.id},
          schedule_in: expires_in
        )
      end

      @cachex.del(:user_cache, "muted_users_ap_ids:#{muter.ap_id}")

      {:ok, Enum.filter([user_mute, user_notification_mute], & &1)}
    end
  end

  def unmute(%User{} = muter, %User{} = mutee) do
    with {:ok, user_mute} <- UserRelationship.delete_mute(muter, mutee),
         {:ok, user_notification_mute} <-
           UserRelationship.delete_notification_mute(muter, mutee) do
      @cachex.del(:user_cache, "muted_users_ap_ids:#{muter.ap_id}")
      {:ok, [user_mute, user_notification_mute]}
    end
  end

  def unmute(muter_id, mutee_id) do
    with {:muter, %User{} = muter} <- {:muter, User.get_by_id(muter_id)},
         {:mutee, %User{} = mutee} <- {:mutee, User.get_by_id(mutee_id)} do
      unmute(muter, mutee)
    else
      {who, result} = error ->
        Logger.warn(
          "User.unmute/2 failed. #{who}: #{result}, muter_id: #{muter_id}, mutee_id: #{mutee_id}"
        )

        {:error, error}
    end
  end

  def subscribe(%User{} = subscriber, %User{} = target) do
    deny_follow_blocked = Config.get([:user, :deny_follow_blocked])

    if blocks?(target, subscriber) and deny_follow_blocked do
      {:error, "Could not subscribe: #{target.nickname} is blocking you"}
    else
      # Note: the relationship is inverse: subscriber acts as relationship target
      UserRelationship.create_inverse_subscription(target, subscriber)
    end
  end

  def subscribe(%User{} = subscriber, %{ap_id: ap_id}) do
    with %User{} = subscribee <- get_cached_by_ap_id(ap_id) do
      subscribe(subscriber, subscribee)
    end
  end

  def unsubscribe(%User{} = unsubscriber, %User{} = target) do
    # Note: the relationship is inverse: subscriber acts as relationship target
    UserRelationship.delete_inverse_subscription(target, unsubscriber)
  end

  def unsubscribe(%User{} = unsubscriber, %{ap_id: ap_id}) do
    with %User{} = user <- get_cached_by_ap_id(ap_id) do
      unsubscribe(unsubscriber, user)
    end
  end

  def block(%User{} = blocker, %User{} = blocked) do
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

    unsubscribe(blocked, blocker)

    unfollowing_blocked = Config.get([:activitypub, :unfollow_blocked], true)
    if unfollowing_blocked && following?(blocked, blocker), do: unfollow(blocked, blocker)

    {:ok, blocker} = update_follower_count(blocker)
    {:ok, blocker, _} = Participation.mark_all_as_read(blocker, blocked)
    add_to_block(blocker, blocked)
  end

  # helper to handle the block given only an actor's AP id
  def block(%User{} = blocker, %{ap_id: ap_id}) do
    block(blocker, get_cached_by_ap_id(ap_id))
  end

  def unblock(%User{} = blocker, %User{} = blocked) do
    remove_from_block(blocker, blocked)
  end

  # helper to handle the block given only an actor's AP id
  def unblock(%User{} = blocker, %{ap_id: ap_id}) do
    unblock(blocker, get_cached_by_ap_id(ap_id))
  end

  def mutes?(nil, _), do: false
  def mutes?(%User{} = user, %User{} = target), do: mutes_user?(user, target)

  def mutes_user?(%User{} = user, %User{} = target) do
    UserRelationship.mute_exists?(user, target)
  end

  @spec muted_notifications?(User.t() | nil, User.t() | map()) :: boolean()
  def muted_notifications?(nil, _), do: false

  def muted_notifications?(%User{} = user, %User{} = target),
    do: UserRelationship.notification_mute_exists?(user, target)

  def blocks?(nil, _), do: false

  def blocks?(%User{} = user, %User{} = target) do
    blocks_user?(user, target) ||
      (blocks_domain?(user, target) and not User.following?(user, target))
  end

  def blocks_user?(%User{} = user, %User{} = target) do
    UserRelationship.block_exists?(user, target)
  end

  def blocks_user?(_, _), do: false

  def blocks_domain?(%User{} = user, %User{} = target) do
    domain_blocks = Pleroma.Web.ActivityPub.MRF.subdomains_regex(user.domain_blocks)
    %{host: host} = URI.parse(target.ap_id)
    Pleroma.Web.ActivityPub.MRF.subdomain_match?(domain_blocks, host)
  end

  def blocks_domain?(_, _), do: false

  def subscribed_to?(%User{} = user, %User{} = target) do
    # Note: the relationship is inverse: subscriber acts as relationship target
    UserRelationship.inverse_subscription_exists?(target, user)
  end

  def subscribed_to?(%User{} = user, %{ap_id: ap_id}) do
    with %User{} = target <- get_cached_by_ap_id(ap_id) do
      subscribed_to?(user, target)
    end
  end

  @doc """
  Returns map of outgoing (blocked, muted etc.) relationships' user AP IDs by relation type.
  E.g. `outgoing_relationships_ap_ids(user, [:block])` -> `%{block: ["https://some.site/users/userapid"]}`
  """
  @spec outgoing_relationships_ap_ids(User.t(), list(atom())) :: %{atom() => list(String.t())}
  def outgoing_relationships_ap_ids(_user, []), do: %{}

  def outgoing_relationships_ap_ids(nil, _relationship_types), do: %{}

  def outgoing_relationships_ap_ids(%User{} = user, relationship_types)
      when is_list(relationship_types) do
    db_result =
      user
      |> assoc(:outgoing_relationships)
      |> join(:inner, [user_rel], u in assoc(user_rel, :target))
      |> where([user_rel, u], user_rel.relationship_type in ^relationship_types)
      |> select([user_rel, u], [user_rel.relationship_type, fragment("array_agg(?)", u.ap_id)])
      |> group_by([user_rel, u], user_rel.relationship_type)
      |> Repo.all()
      |> Enum.into(%{}, fn [k, v] -> {k, v} end)

    Enum.into(
      relationship_types,
      %{},
      fn rel_type -> {rel_type, db_result[rel_type] || []} end
    )
  end

  def incoming_relationships_ungrouped_ap_ids(user, relationship_types, ap_ids \\ nil)

  def incoming_relationships_ungrouped_ap_ids(_user, [], _ap_ids), do: []

  def incoming_relationships_ungrouped_ap_ids(nil, _relationship_types, _ap_ids), do: []

  def incoming_relationships_ungrouped_ap_ids(%User{} = user, relationship_types, ap_ids)
      when is_list(relationship_types) do
    user
    |> assoc(:incoming_relationships)
    |> join(:inner, [user_rel], u in assoc(user_rel, :source))
    |> where([user_rel, u], user_rel.relationship_type in ^relationship_types)
    |> maybe_filter_on_ap_id(ap_ids)
    |> select([user_rel, u], u.ap_id)
    |> distinct(true)
    |> Repo.all()
  end

  defp maybe_filter_on_ap_id(query, ap_ids) when is_list(ap_ids) do
    where(query, [user_rel, u], u.ap_id in ^ap_ids)
  end

  defp maybe_filter_on_ap_id(query, _ap_ids), do: query

  def set_activation_async(user, status \\ true) do
    BackgroundWorker.enqueue("user_activation", %{"user_id" => user.id, "status" => status})
  end

  @spec set_activation([User.t()], boolean()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def set_activation(users, status) when is_list(users) do
    Repo.transaction(fn ->
      for user <- users, do: set_activation(user, status)
    end)
  end

  @spec set_activation(User.t(), boolean()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def set_activation(%User{} = user, status) do
    with {:ok, user} <- set_activation_status(user, status) do
      user
      |> get_followers()
      |> Enum.filter(& &1.local)
      |> Enum.each(&set_cache(update_following_count(&1)))

      # Only update local user counts, remote will be update during the next pull.
      user
      |> get_friends()
      |> Enum.filter(& &1.local)
      |> Enum.each(&do_unfollow(user, &1))

      {:ok, user}
    end
  end

  def approve(users) when is_list(users) do
    Repo.transaction(fn ->
      Enum.map(users, fn user ->
        with {:ok, user} <- approve(user), do: user
      end)
    end)
  end

  def approve(%User{is_approved: false} = user) do
    with chg <- change(user, is_approved: true),
         {:ok, user} <- update_and_set_cache(chg) do
      post_register_action(user)
      {:ok, user}
    end
  end

  def approve(%User{} = user), do: {:ok, user}

  def confirm(users) when is_list(users) do
    Repo.transaction(fn ->
      Enum.map(users, fn user ->
        with {:ok, user} <- confirm(user), do: user
      end)
    end)
  end

  def confirm(%User{is_confirmed: false} = user) do
    with chg <- confirmation_changeset(user, set_confirmation: true),
         {:ok, user} <- update_and_set_cache(chg) do
      post_register_action(user)
      {:ok, user}
    end
  end

  def confirm(%User{} = user), do: {:ok, user}

  def set_suggestion(users, is_suggested) when is_list(users) do
    Repo.transaction(fn ->
      Enum.map(users, fn user ->
        with {:ok, user} <- set_suggestion(user, is_suggested), do: user
      end)
    end)
  end

  def set_suggestion(%User{is_suggested: is_suggested} = user, is_suggested), do: {:ok, user}

  def set_suggestion(%User{} = user, is_suggested) when is_boolean(is_suggested) do
    user
    |> change(is_suggested: is_suggested)
    |> update_and_set_cache()
  end

  def update_notification_settings(%User{} = user, settings) do
    user
    |> cast(%{notification_settings: settings}, [])
    |> cast_embed(:notification_settings)
    |> validate_required([:notification_settings])
    |> update_and_set_cache()
  end

  @spec purge_user_changeset(User.t()) :: Changeset.t()
  def purge_user_changeset(user) do
    # "Right to be forgotten"
    # https://gdpr.eu/right-to-be-forgotten/
    change(user, %{
      bio: "",
      raw_bio: nil,
      email: nil,
      name: nil,
      password_hash: nil,
      avatar: %{},
      tags: [],
      last_refreshed_at: nil,
      last_digest_emailed_at: nil,
      banner: %{},
      background: %{},
      note_count: 0,
      follower_count: 0,
      following_count: 0,
      is_locked: false,
      password_reset_pending: false,
      registration_reason: nil,
      confirmation_token: nil,
      domain_blocks: [],
      is_active: false,
      ap_enabled: false,
      is_moderator: false,
      is_admin: false,
      mascot: nil,
      emoji: %{},
      pleroma_settings_store: %{},
      fields: [],
      raw_fields: [],
      is_discoverable: false,
      also_known_as: []
      # id: preserved
      # ap_id: preserved
      # nickname: preserved
    })
  end

  # Purge doesn't delete the user from the database.
  # It just nulls all its fields and deactivates it.
  # See `User.purge_user_changeset/1` above.
  defp purge(%User{} = user) do
    user
    |> purge_user_changeset()
    |> update_and_set_cache()
  end

  def delete(users) when is_list(users) do
    for user <- users, do: delete(user)
  end

  def delete(%User{} = user) do
    # Purge the user immediately
    purge(user)
    BackgroundWorker.enqueue("delete_user", %{"user_id" => user.id})
  end

  # *Actually* delete the user from the DB
  defp delete_from_db(%User{} = user) do
    invalidate_cache(user)
    Repo.delete(user)
  end

  # If the user never finalized their account, it's safe to delete them.
  defp maybe_delete_from_db(%User{local: true, is_confirmed: false} = user),
    do: delete_from_db(user)

  defp maybe_delete_from_db(%User{local: true, is_approved: false} = user),
    do: delete_from_db(user)

  defp maybe_delete_from_db(user), do: {:ok, user}

  def perform(:force_password_reset, user), do: force_password_reset(user)

  @spec perform(atom(), User.t()) :: {:ok, User.t()}
  def perform(:delete, %User{} = user) do
    # Purge the user again, in case perform/2 is called directly
    purge(user)

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
    delete_notifications_from_user_activities(user)
    delete_outgoing_pending_follow_requests(user)

    maybe_delete_from_db(user)
  end

  def perform(:set_activation_async, user, status), do: set_activation(user, status)

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
      |> select([u], struct(u, [:id, :ap_id]))

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

  def delete_notifications_from_user_activities(%User{ap_id: ap_id}) do
    Notification
    |> join(:inner, [n], activity in assoc(n, :activity))
    |> where([n, a], fragment("? = ?", a.actor, ^ap_id))
    |> Repo.delete_all()
  end

  def delete_user_activities(%User{ap_id: ap_id} = user) do
    ap_id
    |> Activity.Queries.by_actor()
    |> Repo.chunk_stream(50, :batches)
    |> Stream.each(fn activities ->
      Enum.each(activities, fn activity -> delete_activity(activity, user) end)
    end)
    |> Stream.run()
  end

  defp delete_activity(%{data: %{"type" => "Create", "object" => object}} = activity, user) do
    with {_, %Object{}} <- {:find_object, Object.get_by_ap_id(object)},
         {:ok, delete_data, _} <- Builder.delete(user, object) do
      Pipeline.common_pipeline(delete_data, local: user.local)
    else
      {:find_object, nil} ->
        # We have the create activity, but not the object, it was probably pruned.
        # Insert a tombstone and try again
        with {:ok, tombstone_data, _} <- Builder.tombstone(user.ap_id, object),
             {:ok, _tombstone} <- Object.create(tombstone_data) do
          delete_activity(activity, user)
        end

      e ->
        Logger.error("Could not delete #{object} created by #{activity.data["ap_id"]}")
        Logger.error("Error: #{inspect(e)}")
    end
  end

  defp delete_activity(%{data: %{"type" => type}} = activity, user)
       when type in ["Like", "Announce"] do
    {:ok, undo, _} = Builder.undo(user, activity)
    Pipeline.common_pipeline(undo, local: user.local)
  end

  defp delete_activity(_activity, _user), do: "Doing nothing"

  defp delete_outgoing_pending_follow_requests(user) do
    user
    |> FollowingRelationship.outgoing_pending_follow_requests_query()
    |> Repo.delete_all()
  end

  def html_filter_policy(%User{no_rich_text: true}) do
    Pleroma.HTML.Scrubber.TwitterText
  end

  def html_filter_policy(_), do: Config.get([:markup, :scrub_policy])

  def fetch_by_ap_id(ap_id), do: ActivityPub.make_user_from_ap_id(ap_id)

  def get_or_fetch_by_ap_id(ap_id) do
    cached_user = get_cached_by_ap_id(ap_id)

    maybe_fetched_user = needs_update?(cached_user) && fetch_by_ap_id(ap_id)

    case {cached_user, maybe_fetched_user} do
      {_, {:ok, %User{} = user}} ->
        {:ok, user}

      {%User{} = user, _} ->
        {:ok, user}

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Creates an internal service actor by URI if missing.
  Optionally takes nickname for addressing.
  """
  @spec get_or_create_service_actor_by_ap_id(String.t(), String.t()) :: User.t() | nil
  def get_or_create_service_actor_by_ap_id(uri, nickname) do
    {_, user} =
      case get_cached_by_ap_id(uri) do
        nil ->
          with {:error, %{errors: errors}} <- create_service_actor(uri, nickname) do
            Logger.error("Cannot create service actor: #{uri}/.\n#{inspect(errors)}")
            {:error, nil}
          end

        %User{invisible: false} = user ->
          set_invisible(user)

        user ->
          {:ok, user}
      end

    user
  end

  @spec set_invisible(User.t()) :: {:ok, User.t()}
  defp set_invisible(user) do
    user
    |> change(%{invisible: true})
    |> update_and_set_cache()
  end

  @spec create_service_actor(String.t(), String.t()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  defp create_service_actor(uri, nickname) do
    %User{
      invisible: true,
      local: true,
      ap_id: uri,
      nickname: nickname,
      follower_address: uri <> "/followers"
    }
    |> change
    |> unique_constraint(:nickname)
    |> Repo.insert()
    |> set_cache()
  end

  def public_key(%{public_key: public_key_pem}) when is_binary(public_key_pem) do
    key =
      public_key_pem
      |> :public_key.pem_decode()
      |> hd()
      |> :public_key.pem_entry_decode()

    {:ok, key}
  end

  def public_key(_), do: {:error, "key not found"}

  def get_public_key_for_ap_id(ap_id) do
    with {:ok, %User{} = user} <- get_or_fetch_by_ap_id(ap_id),
         {:ok, public_key} <- public_key(user) do
      {:ok, public_key}
    else
      _ -> :error
    end
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
    if Config.get([:instance, :extended_nickname_format]) do
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

  def full_nickname(%User{} = user) do
    if String.contains?(user.nickname, "@") do
      user.nickname
    else
      %{host: host} = URI.parse(user.ap_id)
      user.nickname <> "@" <> host
    end
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
    User.Query.build(%{super_users: true, local: true, is_active: true})
    |> Repo.all()
  end

  def muting_reblogs?(%User{} = user, %User{} = target) do
    UserRelationship.reblog_mute_exists?(user, target)
  end

  def showing_reblogs?(%User{} = user, %User{} = target) do
    not muting_reblogs?(user, target)
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
      where: u.is_active == ^true,
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

  @spec set_confirmation(User.t(), boolean()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def set_confirmation(%User{} = user, bool) do
    user
    |> confirmation_changeset(set_confirmation: bool)
    |> update_and_set_cache()
  end

  def get_mascot(%{mascot: %{} = mascot}) when not is_nil(mascot) do
    mascot
  end

  def get_mascot(%{mascot: mascot}) when is_nil(mascot) do
    # use instance-default
    config = Config.get([:assets, :mascots])
    default_mascot = Config.get([:assets, :default_mascot])
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

  defp put_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    change(changeset, password_hash: Pleroma.Password.Pbkdf2.hash_pwd_salt(password))
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
    |> maybe_validate_required_email(false)
    |> unique_constraint(:email)
    |> validate_format(:email, @email_regex)
    |> update_and_set_cache()
  end

  # Internal function; public one is `deactivate/2`
  defp set_activation_status(user, status) do
    user
    |> cast(%{is_active: status}, [:is_active])
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

  def validate_fields(changeset, remote? \\ false) do
    limit_name = if remote?, do: :max_remote_account_fields, else: :max_account_fields
    limit = Config.get([:instance, limit_name], 0)

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
    name_limit = Config.get([:instance, :account_field_name_length], 255)
    value_limit = Config.get([:instance, :account_field_value_length], 255)

    is_binary(name) && is_binary(value) && String.length(name) <= name_limit &&
      String.length(value) <= value_limit
  end

  defp valid_field?(_), do: false

  defp truncate_field(%{"name" => name, "value" => value}) do
    {name, _chopped} =
      String.split_at(name, Config.get([:instance, :account_field_name_length], 255))

    {value, _chopped} =
      String.split_at(value, Config.get([:instance, :account_field_value_length], 255))

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

  @doc "Signs user out of all applications"
  def global_sign_out(user) do
    OAuth.Authorization.delete_user_authorizations(user)
    OAuth.Token.delete_user_tokens(user)
  end

  def mascot_update(user, url) do
    user
    |> cast(%{mascot: url}, [:mascot])
    |> validate_required([:mascot])
    |> update_and_set_cache()
  end

  @spec confirmation_changeset(User.t(), keyword()) :: Changeset.t()
  def confirmation_changeset(user, set_confirmation: confirmed?) do
    params =
      if confirmed? do
        %{
          is_confirmed: true,
          confirmation_token: nil
        }
      else
        %{
          is_confirmed: false,
          confirmation_token: :crypto.strong_rand_bytes(32) |> Base.url_encode64()
        }
      end

    cast(user, params, [:is_confirmed, :confirmation_token])
  end

  @spec approval_changeset(User.t(), keyword()) :: Changeset.t()
  def approval_changeset(user, set_approval: approved?) do
    cast(user, %{is_approved: approved?}, [:is_approved])
  end

  @spec add_pinned_object_id(User.t(), String.t()) :: {:ok, User.t()} | {:error, term()}
  def add_pinned_object_id(%User{} = user, object_id) do
    if !user.pinned_objects[object_id] do
      params = %{pinned_objects: Map.put(user.pinned_objects, object_id, NaiveDateTime.utc_now())}

      user
      |> cast(params, [:pinned_objects])
      |> validate_change(:pinned_objects, fn :pinned_objects, pinned_objects ->
        max_pinned_statuses = Config.get([:instance, :max_pinned_statuses], 0)

        if Enum.count(pinned_objects) <= max_pinned_statuses do
          []
        else
          [pinned_objects: "You have already pinned the maximum number of statuses"]
        end
      end)
    else
      change(user)
    end
    |> update_and_set_cache()
  end

  @spec remove_pinned_object_id(User.t(), String.t()) :: {:ok, t()} | {:error, term()}
  def remove_pinned_object_id(%User{} = user, object_id) do
    user
    |> cast(
      %{pinned_objects: Map.delete(user.pinned_objects, object_id)},
      [:pinned_objects]
    )
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

  @spec add_to_block(User.t(), User.t()) ::
          {:ok, UserRelationship.t()} | {:error, Ecto.Changeset.t()}
  defp add_to_block(%User{} = user, %User{} = blocked) do
    with {:ok, relationship} <- UserRelationship.create_block(user, blocked) do
      @cachex.del(:user_cache, "blocked_users_ap_ids:#{user.ap_id}")
      {:ok, relationship}
    end
  end

  @spec add_to_block(User.t(), User.t()) ::
          {:ok, UserRelationship.t()} | {:ok, nil} | {:error, Ecto.Changeset.t()}
  defp remove_from_block(%User{} = user, %User{} = blocked) do
    with {:ok, relationship} <- UserRelationship.delete_block(user, blocked) do
      @cachex.del(:user_cache, "blocked_users_ap_ids:#{user.ap_id}")
      {:ok, relationship}
    end
  end

  def set_invisible(user, invisible) do
    params = %{invisible: invisible}

    user
    |> cast(params, [:invisible])
    |> validate_required([:invisible])
    |> update_and_set_cache()
  end

  def sanitize_html(%User{} = user) do
    sanitize_html(user, nil)
  end

  # User data that mastodon isn't filtering (treated as plaintext):
  # - field name
  # - display name
  def sanitize_html(%User{} = user, filter) do
    fields =
      Enum.map(user.fields, fn %{"name" => name, "value" => value} ->
        %{
          "name" => name,
          "value" => HTML.filter_tags(value, Pleroma.HTML.Scrubber.LinksOnly)
        }
      end)

    user
    |> Map.put(:bio, HTML.filter_tags(user.bio, filter))
    |> Map.put(:fields, fields)
  end

  def get_host(%User{ap_id: ap_id} = _user) do
    URI.parse(ap_id).host
  end

  def update_last_active_at(%__MODULE__{local: true} = user) do
    user
    |> cast(%{last_active_at: NaiveDateTime.utc_now()}, [:last_active_at])
    |> update_and_set_cache()
  end

  def active_user_count(days \\ 30) do
    active_after = Timex.shift(NaiveDateTime.utc_now(), days: -days)

    __MODULE__
    |> where([u], u.last_active_at >= ^active_after)
    |> where([u], u.local == true)
    |> Repo.aggregate(:count)
  end

  def update_last_status_at(user) do
    User
    |> where(id: ^user.id)
    |> update([u], set: [last_status_at: fragment("NOW()")])
    |> select([u], u)
    |> Repo.update_all([])
    |> case do
      {1, [user]} -> set_cache(user)
      _ -> {:error, user}
    end
  end
end
