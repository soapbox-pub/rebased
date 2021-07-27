# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AdminAPIController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [json_response: 3, fetch_integer_param: 3]

  alias Pleroma.Config
  alias Pleroma.MFA
  alias Pleroma.ModerationLog
  alias Pleroma.Stats
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.AdminAPI
  alias Pleroma.Web.AdminAPI.AccountView
  alias Pleroma.Web.AdminAPI.ModerationLogView
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.Router

  @users_page_size 50

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:read:accounts"]}
    when action in [:right_get, :show_user_credentials, :create_backup]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:write:accounts"]}
    when action in [
           :get_password_reset,
           :force_password_reset,
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
    %{scopes: ["admin:read:statuses"]}
    when action in [:list_user_statuses]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:read:chats"]}
    when action in [:list_user_chats]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:read"]}
    when action in [
           :list_log,
           :stats,
           :need_reboot
         ]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:write"]}
    when action in [
           :restart,
           :resend_confirmation_email,
           :confirm_email,
           :reload_emoji
         ]
  )

  action_fallback(AdminAPI.FallbackController)

  def list_user_statuses(%{assigns: %{user: admin}} = conn, %{"nickname" => nickname} = params) do
    with_reblogs = params["with_reblogs"] == "true" || params["with_reblogs"] == true
    godmode = params["godmode"] == "true" || params["godmode"] == true

    with %User{} = user <- User.get_cached_by_nickname_or_id(nickname, for: admin) do
      {page, page_size} = page_params(params)

      result =
        ActivityPub.fetch_user_activities(user, nil, %{
          limit: page_size,
          offset: (page - 1) * page_size,
          godmode: godmode,
          exclude_reblogs: not with_reblogs,
          pagination_type: :offset,
          total: true
        })

      conn
      |> put_view(AdminAPI.StatusView)
      |> render("index.json", %{total: result[:total], activities: result[:items], as: :activity})
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
      {:error, "You must enable configurable_from_database in your config file."}
    end
  end

  def reload_emoji(conn, _params) do
    Pleroma.Emoji.reload()

    json(conn, "ok")
  end

  def confirm_email(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames}) do
    users = Enum.map(nicknames, &User.get_cached_by_nickname/1)

    User.confirm(users)

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

  def create_backup(%{assigns: %{user: admin}} = conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_by_nickname(nickname),
         {:ok, _} <- Pleroma.User.Backup.create(user, admin.id) do
      ModerationLog.insert_log(%{actor: admin, subject: user, action: "create_backup"})

      json(conn, "")
    end
  end

  defp page_params(params) do
    {
      fetch_integer_param(params, "page", 1),
      fetch_integer_param(params, "page_size", @users_page_size)
    }
  end
end
