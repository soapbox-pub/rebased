# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AdminAPIController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [json_response: 3]

  alias Pleroma.Config
  alias Pleroma.MFA
  alias Pleroma.ModerationLog
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Stats
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.Pipeline
  alias Pleroma.Web.AdminAPI
  alias Pleroma.Web.AdminAPI.AccountView
  alias Pleroma.Web.AdminAPI.ModerationLogView
  alias Pleroma.Web.AdminAPI.Search
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Router

  @users_page_size 50

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:accounts"], admin: true}
    when action in [:list_users, :user_show, :right_get, :show_user_credentials]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:accounts"], admin: true}
    when action in [
           :get_password_reset,
           :force_password_reset,
           :user_delete,
           :users_create,
           :user_toggle_activation,
           :user_activate,
           :user_deactivate,
           :user_approve,
           :tag_users,
           :untag_users,
           :right_add,
           :right_add_multiple,
           :right_delete,
           :disable_mfa,
           :right_delete_multiple,
           :update_user_credentials
         ]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:follows"], admin: true}
    when action in [:user_follow, :user_unfollow]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:statuses"], admin: true}
    when action in [:list_user_statuses, :list_instance_statuses]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:chats"], admin: true}
    when action in [:list_user_chats]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read"], admin: true}
    when action in [
           :list_log,
           :stats,
           :need_reboot
         ]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write"], admin: true}
    when action in [
           :restart,
           :resend_confirmation_email,
           :confirm_email,
           :reload_emoji
         ]
  )

  action_fallback(AdminAPI.FallbackController)

  def user_delete(conn, %{"nickname" => nickname}) do
    user_delete(conn, %{"nicknames" => [nickname]})
  end

  def user_delete(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames}) do
    users =
      nicknames
      |> Enum.map(&User.get_cached_by_nickname/1)

    users
    |> Enum.each(fn user ->
      {:ok, delete_data, _} = Builder.delete(admin, user.ap_id)
      Pipeline.common_pipeline(delete_data, local: true)
    end)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: users,
      action: "delete"
    })

    json(conn, nicknames)
  end

  def user_follow(%{assigns: %{user: admin}} = conn, %{
        "follower" => follower_nick,
        "followed" => followed_nick
      }) do
    with %User{} = follower <- User.get_cached_by_nickname(follower_nick),
         %User{} = followed <- User.get_cached_by_nickname(followed_nick) do
      User.follow(follower, followed)

      ModerationLog.insert_log(%{
        actor: admin,
        followed: followed,
        follower: follower,
        action: "follow"
      })
    end

    json(conn, "ok")
  end

  def user_unfollow(%{assigns: %{user: admin}} = conn, %{
        "follower" => follower_nick,
        "followed" => followed_nick
      }) do
    with %User{} = follower <- User.get_cached_by_nickname(follower_nick),
         %User{} = followed <- User.get_cached_by_nickname(followed_nick) do
      User.unfollow(follower, followed)

      ModerationLog.insert_log(%{
        actor: admin,
        followed: followed,
        follower: follower,
        action: "unfollow"
      })
    end

    json(conn, "ok")
  end

  def users_create(%{assigns: %{user: admin}} = conn, %{"users" => users}) do
    changesets =
      Enum.map(users, fn %{"nickname" => nickname, "email" => email, "password" => password} ->
        user_data = %{
          nickname: nickname,
          name: nickname,
          email: email,
          password: password,
          password_confirmation: password,
          bio: "."
        }

        User.register_changeset(%User{}, user_data, need_confirmation: false)
      end)
      |> Enum.reduce(Ecto.Multi.new(), fn changeset, multi ->
        Ecto.Multi.insert(multi, Ecto.UUID.generate(), changeset)
      end)

    case Pleroma.Repo.transaction(changesets) do
      {:ok, users} ->
        res =
          users
          |> Map.values()
          |> Enum.map(fn user ->
            {:ok, user} = User.post_register_action(user)

            user
          end)
          |> Enum.map(&AccountView.render("created.json", %{user: &1}))

        ModerationLog.insert_log(%{
          actor: admin,
          subjects: Map.values(users),
          action: "create"
        })

        json(conn, res)

      {:error, id, changeset, _} ->
        res =
          Enum.map(changesets.operations, fn
            {current_id, {:changeset, _current_changeset, _}} when current_id == id ->
              AccountView.render("create-error.json", %{changeset: changeset})

            {_, {:changeset, current_changeset, _}} ->
              AccountView.render("create-error.json", %{changeset: current_changeset})
          end)

        conn
        |> put_status(:conflict)
        |> json(res)
    end
  end

  def user_show(%{assigns: %{user: admin}} = conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_cached_by_nickname_or_id(nickname, for: admin) do
      conn
      |> put_view(AccountView)
      |> render("show.json", %{user: user})
    else
      _ -> {:error, :not_found}
    end
  end

  def list_instance_statuses(conn, %{"instance" => instance} = params) do
    with_reblogs = params["with_reblogs"] == "true" || params["with_reblogs"] == true
    {page, page_size} = page_params(params)

    activities =
      ActivityPub.fetch_statuses(nil, %{
        instance: instance,
        limit: page_size,
        offset: (page - 1) * page_size,
        exclude_reblogs: not with_reblogs
      })

    conn
    |> put_view(AdminAPI.StatusView)
    |> render("index.json", %{activities: activities, as: :activity})
  end

  def list_user_statuses(%{assigns: %{user: admin}} = conn, %{"nickname" => nickname} = params) do
    with_reblogs = params["with_reblogs"] == "true" || params["with_reblogs"] == true
    godmode = params["godmode"] == "true" || params["godmode"] == true

    with %User{} = user <- User.get_cached_by_nickname_or_id(nickname, for: admin) do
      {_, page_size} = page_params(params)

      activities =
        ActivityPub.fetch_user_activities(user, nil, %{
          limit: page_size,
          godmode: godmode,
          exclude_reblogs: not with_reblogs
        })

      conn
      |> put_view(AdminAPI.StatusView)
      |> render("index.json", %{activities: activities, as: :activity})
    else
      _ -> {:error, :not_found}
    end
  end

  def list_user_chats(%{assigns: %{user: admin}} = conn, %{"nickname" => nickname} = _params) do
    with %User{id: user_id} <- User.get_cached_by_nickname_or_id(nickname, for: admin) do
      chats =
        Pleroma.Chat.for_user_query(user_id)
        |> Pleroma.Repo.all()

      conn
      |> put_view(AdminAPI.ChatView)
      |> render("index.json", chats: chats)
    else
      _ -> {:error, :not_found}
    end
  end

  def user_toggle_activation(%{assigns: %{user: admin}} = conn, %{"nickname" => nickname}) do
    user = User.get_cached_by_nickname(nickname)

    {:ok, updated_user} = User.deactivate(user, !user.deactivated)

    action = if user.deactivated, do: "activate", else: "deactivate"

    ModerationLog.insert_log(%{
      actor: admin,
      subject: [user],
      action: action
    })

    conn
    |> put_view(AccountView)
    |> render("show.json", %{user: updated_user})
  end

  def user_activate(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames}) do
    users = Enum.map(nicknames, &User.get_cached_by_nickname/1)
    {:ok, updated_users} = User.deactivate(users, false)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: users,
      action: "activate"
    })

    conn
    |> put_view(AccountView)
    |> render("index.json", %{users: Keyword.values(updated_users)})
  end

  def user_deactivate(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames}) do
    users = Enum.map(nicknames, &User.get_cached_by_nickname/1)
    {:ok, updated_users} = User.deactivate(users, true)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: users,
      action: "deactivate"
    })

    conn
    |> put_view(AccountView)
    |> render("index.json", %{users: Keyword.values(updated_users)})
  end

  def user_approve(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames}) do
    users = Enum.map(nicknames, &User.get_cached_by_nickname/1)
    {:ok, updated_users} = User.approve(users)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: users,
      action: "approve"
    })

    conn
    |> put_view(AccountView)
    |> render("index.json", %{users: updated_users})
  end

  def tag_users(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames, "tags" => tags}) do
    with {:ok, _} <- User.tag(nicknames, tags) do
      ModerationLog.insert_log(%{
        actor: admin,
        nicknames: nicknames,
        tags: tags,
        action: "tag"
      })

      json_response(conn, :no_content, "")
    end
  end

  def untag_users(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames, "tags" => tags}) do
    with {:ok, _} <- User.untag(nicknames, tags) do
      ModerationLog.insert_log(%{
        actor: admin,
        nicknames: nicknames,
        tags: tags,
        action: "untag"
      })

      json_response(conn, :no_content, "")
    end
  end

  def list_users(conn, params) do
    {page, page_size} = page_params(params)
    filters = maybe_parse_filters(params["filters"])

    search_params = %{
      query: params["query"],
      page: page,
      page_size: page_size,
      tags: params["tags"],
      name: params["name"],
      email: params["email"]
    }

    with {:ok, users, count} <- Search.user(Map.merge(search_params, filters)) do
      json(
        conn,
        AccountView.render("index.json",
          users: users,
          count: count,
          page_size: page_size
        )
      )
    end
  end

  @filters ~w(local external active deactivated need_approval is_admin is_moderator)

  @spec maybe_parse_filters(String.t()) :: %{required(String.t()) => true} | %{}
  defp maybe_parse_filters(filters) when is_nil(filters) or filters == "", do: %{}

  defp maybe_parse_filters(filters) do
    filters
    |> String.split(",")
    |> Enum.filter(&Enum.member?(@filters, &1))
    |> Map.new(&{String.to_existing_atom(&1), true})
  end

  def right_add_multiple(%{assigns: %{user: admin}} = conn, %{
        "permission_group" => permission_group,
        "nicknames" => nicknames
      })
      when permission_group in ["moderator", "admin"] do
    update = %{:"is_#{permission_group}" => true}

    users = nicknames |> Enum.map(&User.get_cached_by_nickname/1)

    for u <- users, do: User.admin_api_update(u, update)

    ModerationLog.insert_log(%{
      action: "grant",
      actor: admin,
      subject: users,
      permission: permission_group
    })

    json(conn, update)
  end

  def right_add_multiple(conn, _) do
    render_error(conn, :not_found, "No such permission_group")
  end

  def right_add(%{assigns: %{user: admin}} = conn, %{
        "permission_group" => permission_group,
        "nickname" => nickname
      })
      when permission_group in ["moderator", "admin"] do
    fields = %{:"is_#{permission_group}" => true}

    {:ok, user} =
      nickname
      |> User.get_cached_by_nickname()
      |> User.admin_api_update(fields)

    ModerationLog.insert_log(%{
      action: "grant",
      actor: admin,
      subject: [user],
      permission: permission_group
    })

    json(conn, fields)
  end

  def right_add(conn, _) do
    render_error(conn, :not_found, "No such permission_group")
  end

  def right_get(conn, %{"nickname" => nickname}) do
    user = User.get_cached_by_nickname(nickname)

    conn
    |> json(%{
      is_moderator: user.is_moderator,
      is_admin: user.is_admin
    })
  end

  def right_delete_multiple(
        %{assigns: %{user: %{nickname: admin_nickname} = admin}} = conn,
        %{
          "permission_group" => permission_group,
          "nicknames" => nicknames
        }
      )
      when permission_group in ["moderator", "admin"] do
    with false <- Enum.member?(nicknames, admin_nickname) do
      update = %{:"is_#{permission_group}" => false}

      users = nicknames |> Enum.map(&User.get_cached_by_nickname/1)

      for u <- users, do: User.admin_api_update(u, update)

      ModerationLog.insert_log(%{
        action: "revoke",
        actor: admin,
        subject: users,
        permission: permission_group
      })

      json(conn, update)
    else
      _ -> render_error(conn, :forbidden, "You can't revoke your own admin/moderator status.")
    end
  end

  def right_delete_multiple(conn, _) do
    render_error(conn, :not_found, "No such permission_group")
  end

  def right_delete(
        %{assigns: %{user: admin}} = conn,
        %{
          "permission_group" => permission_group,
          "nickname" => nickname
        }
      )
      when permission_group in ["moderator", "admin"] do
    fields = %{:"is_#{permission_group}" => false}

    {:ok, user} =
      nickname
      |> User.get_cached_by_nickname()
      |> User.admin_api_update(fields)

    ModerationLog.insert_log(%{
      action: "revoke",
      actor: admin,
      subject: [user],
      permission: permission_group
    })

    json(conn, fields)
  end

  def right_delete(%{assigns: %{user: %{nickname: nickname}}} = conn, %{"nickname" => nickname}) do
    render_error(conn, :forbidden, "You can't revoke your own admin status.")
  end

  @doc "Get a password reset token (base64 string) for given nickname"
  def get_password_reset(conn, %{"nickname" => nickname}) do
    (%User{local: true} = user) = User.get_cached_by_nickname(nickname)
    {:ok, token} = Pleroma.PasswordResetToken.create_token(user)

    conn
    |> json(%{
      token: token.token,
      link: Router.Helpers.reset_password_url(Endpoint, :reset, token.token)
    })
  end

  @doc "Force password reset for a given user"
  def force_password_reset(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames}) do
    users = nicknames |> Enum.map(&User.get_cached_by_nickname/1)

    Enum.each(users, &User.force_password_reset_async/1)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: users,
      action: "force_password_reset"
    })

    json_response(conn, :no_content, "")
  end

  @doc "Disable mfa for user's account."
  def disable_mfa(conn, %{"nickname" => nickname}) do
    case User.get_by_nickname(nickname) do
      %User{} = user ->
        MFA.disable(user)
        json(conn, nickname)

      _ ->
        {:error, :not_found}
    end
  end

  @doc "Show a given user's credentials"
  def show_user_credentials(%{assigns: %{user: admin}} = conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_cached_by_nickname_or_id(nickname, for: admin) do
      conn
      |> put_view(AccountView)
      |> render("credentials.json", %{user: user, for: admin})
    else
      _ -> {:error, :not_found}
    end
  end

  @doc "Updates a given user"
  def update_user_credentials(
        %{assigns: %{user: admin}} = conn,
        %{"nickname" => nickname} = params
      ) do
    with {_, %User{} = user} <- {:user, User.get_cached_by_nickname(nickname)},
         {:ok, _user} <-
           User.update_as_admin(user, params) do
      ModerationLog.insert_log(%{
        actor: admin,
        subject: [user],
        action: "updated_users"
      })

      if params["password"] do
        User.force_password_reset_async(user)
      end

      ModerationLog.insert_log(%{
        actor: admin,
        subject: [user],
        action: "force_password_reset"
      })

      json(conn, %{status: "success"})
    else
      {:error, changeset} ->
        errors = Map.new(changeset.errors, fn {key, {error, _}} -> {key, error} end)

        {:errors, errors}

      _ ->
        {:error, :not_found}
    end
  end

  def list_log(conn, params) do
    {page, page_size} = page_params(params)

    log =
      ModerationLog.get_all(%{
        page: page,
        page_size: page_size,
        start_date: params["start_date"],
        end_date: params["end_date"],
        user_id: params["user_id"],
        search: params["search"]
      })

    conn
    |> put_view(ModerationLogView)
    |> render("index.json", %{log: log})
  end

  def restart(conn, _params) do
    with :ok <- configurable_from_database() do
      Restarter.Pleroma.restart(Config.get(:env), 50)

      json(conn, %{})
    end
  end

  def need_reboot(conn, _params) do
    json(conn, %{need_reboot: Restarter.Pleroma.need_reboot?()})
  end

  defp configurable_from_database do
    if Config.get(:configurable_from_database) do
      :ok
    else
      {:error, "To use this endpoint you need to enable configuration from database."}
    end
  end

  def reload_emoji(conn, _params) do
    Pleroma.Emoji.reload()

    json(conn, "ok")
  end

  def confirm_email(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames}) do
    users = Enum.map(nicknames, &User.get_cached_by_nickname/1)

    User.toggle_confirmation(users)

    ModerationLog.insert_log(%{actor: admin, subject: users, action: "confirm_email"})

    json(conn, "")
  end

  def resend_confirmation_email(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames}) do
    users =
      Enum.map(nicknames, fn nickname ->
        nickname
        |> User.get_cached_by_nickname()
        |> User.send_confirmation_email()
      end)

    ModerationLog.insert_log(%{actor: admin, subject: users, action: "resend_confirmation_email"})

    json(conn, "")
  end

  def stats(conn, params) do
    counters = Stats.get_status_visibility_count(params["instance"])

    json(conn, %{"status_visibility" => counters})
  end

  defp page_params(params) do
    {get_page(params["page"]), get_page_size(params["page_size"])}
  end

  defp get_page(page_string) when is_nil(page_string), do: 1

  defp get_page(page_string) do
    case Integer.parse(page_string) do
      {page, _} -> page
      :error -> 1
    end
  end

  defp get_page_size(page_size_string) when is_nil(page_size_string), do: @users_page_size

  defp get_page_size(page_size_string) do
    case Integer.parse(page_size_string) do
      {page_size, _} -> page_size
      :error -> @users_page_size
    end
  end
end
