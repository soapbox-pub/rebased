# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AccountController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [
      add_link_headers: 2,
      truthy_param?: 1,
      assign_account_by_id: 2,
      json_response: 3,
      skip_relationships?: 1
    ]

  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Plugs.RateLimiter
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.ListView
  alias Pleroma.Web.MastodonAPI.MastodonAPI
  alias Pleroma.Web.MastodonAPI.MastodonAPIController
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.TwitterAPI.TwitterAPI

  plug(:skip_plug, OAuthScopesPlug when action == :identity_proofs)

  plug(
    OAuthScopesPlug,
    %{fallback: :proceed_unauthenticated, scopes: ["read:accounts"]}
    when action == :show
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:accounts"]}
    when action in [:endorsements, :verify_credentials, :followers, :following]
  )

  plug(OAuthScopesPlug, %{scopes: ["write:accounts"]} when action == :update_credentials)

  plug(OAuthScopesPlug, %{scopes: ["read:lists"]} when action == :lists)

  plug(
    OAuthScopesPlug,
    %{scopes: ["follow", "read:blocks"]} when action == :blocks
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["follow", "write:blocks"]} when action in [:block, :unblock]
  )

  plug(OAuthScopesPlug, %{scopes: ["read:follows"]} when action == :relationships)

  # Note: :follows (POST /api/v1/follows) is the same as :follow, consider removing :follows
  plug(
    OAuthScopesPlug,
    %{scopes: ["follow", "write:follows"]} when action in [:follows, :follow, :unfollow]
  )

  plug(OAuthScopesPlug, %{scopes: ["follow", "read:mutes"]} when action == :mutes)

  plug(OAuthScopesPlug, %{scopes: ["follow", "write:mutes"]} when action in [:mute, :unmute])

  plug(
    Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug
    when action not in [:create, :show, :statuses]
  )

  @relationship_actions [:follow, :unfollow]
  @needs_account ~W(followers following lists follow unfollow mute unmute block unblock)a

  plug(
    RateLimiter,
    [name: :relation_id_action, params: ["id", "uri"]] when action in @relationship_actions
  )

  plug(RateLimiter, [name: :relations_actions] when action in @relationship_actions)
  plug(RateLimiter, [name: :app_account_creation] when action == :create)
  plug(:assign_account_by_id when action in @needs_account)

  plug(OpenApiSpex.Plug.CastAndValidate, render_error: Pleroma.Web.ApiSpec.RenderError)

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.AccountOperation

  @doc "POST /api/v1/accounts"
  def create(%{assigns: %{app: app}, body_params: params} = conn, _params) do
    params =
      params
      |> Map.take([
        :email,
        :bio,
        :captcha_solution,
        :captcha_token,
        :captcha_answer_data,
        :token,
        :password,
        :fullname
      ])
      |> Map.put(:nickname, params.username)
      |> Map.put(:fullname, params.fullname || params.username)
      |> Map.put(:bio, params.bio || "")
      |> Map.put(:confirm, params.password)
      |> Map.put(:trusted_app, app.trusted)

    with :ok <- validate_email_param(params),
         {:ok, user} <- TwitterAPI.register_user(params, need_confirmation: true),
         {:ok, token} <- Token.create_token(app, user, %{scopes: app.scopes}) do
      json(conn, %{
        token_type: "Bearer",
        access_token: token.token,
        scope: app.scopes,
        created_at: Token.Utils.format_created_at(token)
      })
    else
      {:error, errors} -> json_response(conn, :bad_request, errors)
    end
  end

  def create(%{assigns: %{app: _app}} = conn, _) do
    render_error(conn, :bad_request, "Missing parameters")
  end

  def create(conn, _) do
    render_error(conn, :forbidden, "Invalid credentials")
  end

  defp validate_email_param(%{:email => email}) when not is_nil(email), do: :ok

  defp validate_email_param(_) do
    case Pleroma.Config.get([:instance, :account_activation_required]) do
      true -> {:error, %{"error" => "Missing parameters"}}
      _ -> :ok
    end
  end

  @doc "GET /api/v1/accounts/verify_credentials"
  def verify_credentials(%{assigns: %{user: user}} = conn, _) do
    chat_token = Phoenix.Token.sign(conn, "user socket", user.id)

    render(conn, "show.json",
      user: user,
      for: user,
      with_pleroma_settings: true,
      with_chat_token: chat_token
    )
  end

  @doc "PATCH /api/v1/accounts/update_credentials"
  def update_credentials(%{assigns: %{user: original_user}, body_params: params} = conn, _params) do
    user = original_user

    params =
      params
      |> Map.from_struct()
      |> Enum.filter(fn {_, value} -> not is_nil(value) end)
      |> Enum.into(%{})

    user_params =
      [
        :no_rich_text,
        :locked,
        :hide_followers_count,
        :hide_follows_count,
        :hide_followers,
        :hide_follows,
        :hide_favorites,
        :show_role,
        :skip_thread_containment,
        :allow_following_move,
        :discoverable
      ]
      |> Enum.reduce(%{}, fn key, acc ->
        add_if_present(acc, params, key, key, &{:ok, truthy_param?(&1)})
      end)
      |> add_if_present(params, :display_name, :name)
      |> add_if_present(params, :note, :bio)
      |> add_if_present(params, :avatar, :avatar)
      |> add_if_present(params, :header, :banner)
      |> add_if_present(params, :pleroma_background_image, :background)
      |> add_if_present(
        params,
        :fields_attributes,
        :raw_fields,
        &{:ok, normalize_fields_attributes(&1)}
      )
      |> add_if_present(params, :pleroma_settings_store, :pleroma_settings_store)
      |> add_if_present(params, :default_scope, :default_scope)
      |> add_if_present(params, :actor_type, :actor_type)

    changeset = User.update_changeset(user, user_params)

    with {:ok, user} <- User.update_and_set_cache(changeset) do
      render(conn, "show.json", user: user, for: user, with_pleroma_settings: true)
    else
      _e -> render_error(conn, :forbidden, "Invalid request")
    end
  end

  defp add_if_present(map, params, params_field, map_field, value_function \\ &{:ok, &1}) do
    with true <- Map.has_key?(params, params_field),
         {:ok, new_value} <- value_function.(Map.get(params, params_field)) do
      Map.put(map, map_field, new_value)
    else
      _ -> map
    end
  end

  defp normalize_fields_attributes(fields) do
    if Enum.all?(fields, &is_tuple/1) do
      Enum.map(fields, fn {_, v} -> v end)
    else
      Enum.map(fields, fn
        %Pleroma.Web.ApiSpec.Schemas.AccountAttributeField{} = field ->
          %{"name" => field.name, "value" => field.value}

        field ->
          field
      end)
    end
  end

  @doc "GET /api/v1/accounts/relationships"
  def relationships(%{assigns: %{user: user}} = conn, %{id: id}) do
    targets = User.get_all_by_ids(List.wrap(id))

    render(conn, "relationships.json", user: user, targets: targets)
  end

  # Instead of returning a 400 when no "id" params is present, Mastodon returns an empty array.
  def relationships(%{assigns: %{user: _user}} = conn, _), do: json(conn, [])

  @doc "GET /api/v1/accounts/:id"
  def show(%{assigns: %{user: for_user}} = conn, %{id: nickname_or_id}) do
    with %User{} = user <- User.get_cached_by_nickname_or_id(nickname_or_id, for: for_user),
         true <- User.visible_for?(user, for_user) do
      render(conn, "show.json", user: user, for: for_user)
    else
      _e -> render_error(conn, :not_found, "Can't find user")
    end
  end

  @doc "GET /api/v1/accounts/:id/statuses"
  def statuses(%{assigns: %{user: reading_user}} = conn, params) do
    with %User{} = user <- User.get_cached_by_nickname_or_id(params.id, for: reading_user),
         true <- User.visible_for?(user, reading_user) do
      params =
        params
        |> Map.delete(:tagged)
        |> Enum.filter(&(not is_nil(&1)))
        |> Map.new(fn {key, value} -> {to_string(key), value} end)
        |> Map.put("tag", params[:tagged])

      activities = ActivityPub.fetch_user_activities(user, reading_user, params)

      conn
      |> add_link_headers(activities)
      |> put_view(StatusView)
      |> render("index.json",
        activities: activities,
        for: reading_user,
        as: :activity,
        skip_relationships: skip_relationships?(params)
      )
    else
      _e -> render_error(conn, :not_found, "Can't find user")
    end
  end

  @doc "GET /api/v1/accounts/:id/followers"
  def followers(%{assigns: %{user: for_user, account: user}} = conn, params) do
    params =
      params
      |> Enum.map(fn {key, value} -> {to_string(key), value} end)
      |> Enum.into(%{})

    followers =
      cond do
        for_user && user.id == for_user.id -> MastodonAPI.get_followers(user, params)
        user.hide_followers -> []
        true -> MastodonAPI.get_followers(user, params)
      end

    conn
    |> add_link_headers(followers)
    |> render("index.json", for: for_user, users: followers, as: :user)
  end

  @doc "GET /api/v1/accounts/:id/following"
  def following(%{assigns: %{user: for_user, account: user}} = conn, params) do
    params =
      params
      |> Enum.map(fn {key, value} -> {to_string(key), value} end)
      |> Enum.into(%{})

    followers =
      cond do
        for_user && user.id == for_user.id -> MastodonAPI.get_friends(user, params)
        user.hide_follows -> []
        true -> MastodonAPI.get_friends(user, params)
      end

    conn
    |> add_link_headers(followers)
    |> render("index.json", for: for_user, users: followers, as: :user)
  end

  @doc "GET /api/v1/accounts/:id/lists"
  def lists(%{assigns: %{user: user, account: account}} = conn, _params) do
    lists = Pleroma.List.get_lists_account_belongs(user, account)

    conn
    |> put_view(ListView)
    |> render("index.json", lists: lists)
  end

  @doc "POST /api/v1/accounts/:id/follow"
  def follow(%{assigns: %{user: %{id: id}, account: %{id: id}}}, _params) do
    {:error, "Can not follow yourself"}
  end

  def follow(%{assigns: %{user: follower, account: followed}} = conn, params) do
    with {:ok, follower} <- MastodonAPI.follow(follower, followed, params) do
      render(conn, "relationship.json", user: follower, target: followed)
    else
      {:error, message} -> json_response(conn, :forbidden, %{error: message})
    end
  end

  @doc "POST /api/v1/accounts/:id/unfollow"
  def unfollow(%{assigns: %{user: %{id: id}, account: %{id: id}}}, _params) do
    {:error, "Can not unfollow yourself"}
  end

  def unfollow(%{assigns: %{user: follower, account: followed}} = conn, _params) do
    with {:ok, follower} <- CommonAPI.unfollow(follower, followed) do
      render(conn, "relationship.json", user: follower, target: followed)
    end
  end

  @doc "POST /api/v1/accounts/:id/mute"
  def mute(%{assigns: %{user: muter, account: muted}, body_params: params} = conn, _params) do
    with {:ok, _user_relationships} <- User.mute(muter, muted, params.notifications) do
      render(conn, "relationship.json", user: muter, target: muted)
    else
      {:error, message} -> json_response(conn, :forbidden, %{error: message})
    end
  end

  @doc "POST /api/v1/accounts/:id/unmute"
  def unmute(%{assigns: %{user: muter, account: muted}} = conn, _params) do
    with {:ok, _user_relationships} <- User.unmute(muter, muted) do
      render(conn, "relationship.json", user: muter, target: muted)
    else
      {:error, message} -> json_response(conn, :forbidden, %{error: message})
    end
  end

  @doc "POST /api/v1/accounts/:id/block"
  def block(%{assigns: %{user: blocker, account: blocked}} = conn, _params) do
    with {:ok, _user_block} <- User.block(blocker, blocked),
         {:ok, _activity} <- ActivityPub.block(blocker, blocked) do
      render(conn, "relationship.json", user: blocker, target: blocked)
    else
      {:error, message} -> json_response(conn, :forbidden, %{error: message})
    end
  end

  @doc "POST /api/v1/accounts/:id/unblock"
  def unblock(%{assigns: %{user: blocker, account: blocked}} = conn, _params) do
    with {:ok, _user_block} <- User.unblock(blocker, blocked),
         {:ok, _activity} <- ActivityPub.unblock(blocker, blocked) do
      render(conn, "relationship.json", user: blocker, target: blocked)
    else
      {:error, message} -> json_response(conn, :forbidden, %{error: message})
    end
  end

  @doc "POST /api/v1/follows"
  def follows(%{body_params: %{uri: uri}} = conn, _) do
    case User.get_cached_by_nickname(uri) do
      %User{} = user ->
        conn
        |> assign(:account, user)
        |> follow(%{})

      nil ->
        {:error, :not_found}
    end
  end

  @doc "GET /api/v1/mutes"
  def mutes(%{assigns: %{user: user}} = conn, _) do
    users = User.muted_users(user, _restrict_deactivated = true)
    render(conn, "index.json", users: users, for: user, as: :user)
  end

  @doc "GET /api/v1/blocks"
  def blocks(%{assigns: %{user: user}} = conn, _) do
    users = User.blocked_users(user, _restrict_deactivated = true)
    render(conn, "index.json", users: users, for: user, as: :user)
  end

  @doc "GET /api/v1/endorsements"
  def endorsements(conn, params), do: MastodonAPIController.empty_array(conn, params)

  @doc "GET /api/v1/identity_proofs"
  def identity_proofs(conn, params), do: MastodonAPIController.empty_array(conn, params)
end
