# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AdminAPIController do
  use Pleroma.Web, :controller
  alias Pleroma.Activity
  alias Pleroma.ModerationLog
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.ReportNote
  alias Pleroma.User
  alias Pleroma.UserInviteToken
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.AdminAPI.AccountView
  alias Pleroma.Web.AdminAPI.Config
  alias Pleroma.Web.AdminAPI.ConfigView
  alias Pleroma.Web.AdminAPI.ModerationLogView
  alias Pleroma.Web.AdminAPI.Report
  alias Pleroma.Web.AdminAPI.ReportView
  alias Pleroma.Web.AdminAPI.Search
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.Router

  import Pleroma.Web.ControllerHelper, only: [json_response: 3]

  require Logger

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:accounts"], admin: true}
    when action in [:list_users, :user_show, :right_get, :invites]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:accounts"], admin: true}
    when action in [
           :get_invite_token,
           :revoke_invite,
           :email_invite,
           :get_password_reset,
           :user_follow,
           :user_unfollow,
           :user_delete,
           :users_create,
           :user_toggle_activation,
           :user_activate,
           :user_deactivate,
           :tag_users,
           :untag_users,
           :right_add,
           :right_delete
         ]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:reports"], admin: true}
    when action in [:list_reports, :report_show]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:reports"], admin: true}
    when action in [:report_update_state, :report_respond]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:statuses"], admin: true}
    when action == :list_user_statuses
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:statuses"], admin: true}
    when action in [:status_update, :status_delete]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read"], admin: true}
    when action in [:config_show, :migrate_to_db, :migrate_from_db, :list_log]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write"], admin: true}
    when action in [:relay_follow, :relay_unfollow, :config_update]
  )

  @users_page_size 50

  action_fallback(:errors)

  def user_delete(%{assigns: %{user: admin}} = conn, %{"nickname" => nickname}) do
    user = User.get_cached_by_nickname(nickname)
    User.delete(user)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: [user],
      action: "delete"
    })

    conn
    |> json(nickname)
  end

  def user_delete(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames}) do
    users = nicknames |> Enum.map(&User.get_cached_by_nickname/1)
    User.delete(users)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: users,
      action: "delete"
    })

    conn
    |> json(nicknames)
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

    conn
    |> json("ok")
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

    conn
    |> json("ok")
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

        conn
        |> json(res)

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

  def user_show(conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_cached_by_nickname_or_id(nickname) do
      conn
      |> put_view(AccountView)
      |> render("show.json", %{user: user})
    else
      _ -> {:error, :not_found}
    end
  end

  def list_instance_statuses(conn, %{"instance" => instance} = params) do
    {page, page_size} = page_params(params)

    activities =
      ActivityPub.fetch_instance_activities(%{
        "instance" => instance,
        "limit" => page_size,
        "offset" => (page - 1) * page_size
      })

    conn
    |> put_view(StatusView)
    |> render("index.json", %{activities: activities, as: :activity})
  end

  def list_user_statuses(conn, %{"nickname" => nickname} = params) do
    godmode = params["godmode"] == "true" || params["godmode"] == true

    with %User{} = user <- User.get_cached_by_nickname_or_id(nickname) do
      {_, page_size} = page_params(params)

      activities =
        ActivityPub.fetch_user_activities(user, nil, %{
          "limit" => page_size,
          "godmode" => godmode
        })

      conn
      |> put_view(StatusView)
      |> render("index.json", %{activities: activities, as: :activity})
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

    with {:ok, users, count} <- Search.user(Map.merge(search_params, filters)),
         {:ok, users, count} <- filter_service_users(users, count),
         do:
           conn
           |> json(
             AccountView.render("index.json",
               users: users,
               count: count,
               page_size: page_size
             )
           )
  end

  defp filter_service_users(users, count) do
    filtered_users = Enum.reject(users, &service_user?/1)
    count = if Enum.any?(users, &service_user?/1), do: length(filtered_users), else: count

    {:ok, filtered_users, count}
  end

  defp service_user?(user) do
    String.match?(user.ap_id, ~r/.*\/relay$/) or
      String.match?(user.ap_id, ~r/.*\/internal\/fetch$/)
  end

  @filters ~w(local external active deactivated is_admin is_moderator)

  @spec maybe_parse_filters(String.t()) :: %{required(String.t()) => true} | %{}
  defp maybe_parse_filters(filters) when is_nil(filters) or filters == "", do: %{}

  defp maybe_parse_filters(filters) do
    filters
    |> String.split(",")
    |> Enum.filter(&Enum.member?(@filters, &1))
    |> Enum.map(&String.to_atom(&1))
    |> Enum.into(%{}, &{&1, true})
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

  def relay_list(conn, _params) do
    with {:ok, list} <- Relay.list() do
      json(conn, %{relays: list})
    else
      _ ->
        conn
        |> put_status(500)
    end
  end

  def relay_follow(%{assigns: %{user: admin}} = conn, %{"relay_url" => target}) do
    with {:ok, _message} <- Relay.follow(target) do
      ModerationLog.insert_log(%{
        action: "relay_follow",
        actor: admin,
        target: target
      })

      json(conn, target)
    else
      _ ->
        conn
        |> put_status(500)
        |> json(target)
    end
  end

  def relay_unfollow(%{assigns: %{user: admin}} = conn, %{"relay_url" => target}) do
    with {:ok, _message} <- Relay.unfollow(target) do
      ModerationLog.insert_log(%{
        action: "relay_unfollow",
        actor: admin,
        target: target
      })

      json(conn, target)
    else
      _ ->
        conn
        |> put_status(500)
        |> json(target)
    end
  end

  @doc "Sends registration invite via email"
  def email_invite(%{assigns: %{user: user}} = conn, %{"email" => email} = params) do
    with true <-
           Pleroma.Config.get([:instance, :invites_enabled]) &&
             !Pleroma.Config.get([:instance, :registrations_open]),
         {:ok, invite_token} <- UserInviteToken.create_invite(),
         email <-
           Pleroma.Emails.UserEmail.user_invitation_email(
             user,
             invite_token,
             email,
             params["name"]
           ),
         {:ok, _} <- Pleroma.Emails.Mailer.deliver(email) do
      json_response(conn, :no_content, "")
    end
  end

  @doc "Create an account registration invite token"
  def create_invite_token(conn, params) do
    opts = %{}

    opts =
      if params["max_use"],
        do: Map.put(opts, :max_use, params["max_use"]),
        else: opts

    opts =
      if params["expires_at"],
        do: Map.put(opts, :expires_at, params["expires_at"]),
        else: opts

    {:ok, invite} = UserInviteToken.create_invite(opts)

    json(conn, AccountView.render("invite.json", %{invite: invite}))
  end

  @doc "Get list of created invites"
  def invites(conn, _params) do
    invites = UserInviteToken.list_invites()

    conn
    |> put_view(AccountView)
    |> render("invites.json", %{invites: invites})
  end

  @doc "Revokes invite by token"
  def revoke_invite(conn, %{"token" => token}) do
    with {:ok, invite} <- UserInviteToken.find_by_token(token),
         {:ok, updated_invite} = UserInviteToken.update_invite(invite, %{used: true}) do
      conn
      |> put_view(AccountView)
      |> render("invite.json", %{invite: updated_invite})
    else
      nil -> {:error, :not_found}
    end
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

    Enum.map(users, &User.force_password_reset_async/1)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: users,
      action: "force_password_reset"
    })

    json_response(conn, :no_content, "")
  end

  def list_reports(conn, params) do
    {page, page_size} = page_params(params)

    reports = Utils.get_reports(params, page, page_size)

    conn
    |> put_view(ReportView)
    |> render("index.json", %{reports: reports})
  end

  def list_grouped_reports(conn, _params) do
    statuses = Utils.get_reported_activities()

    conn
    |> put_view(ReportView)
    |> render("index_grouped.json", Utils.get_reports_grouped_by_status(statuses))
  end

  def report_show(conn, %{"id" => id}) do
    with %Activity{} = report <- Activity.get_by_id(id) do
      conn
      |> put_view(ReportView)
      |> render("show.json", Report.extract_report_info(report))
    else
      _ -> {:error, :not_found}
    end
  end

  def reports_update(%{assigns: %{user: admin}} = conn, %{"reports" => reports}) do
    result =
      reports
      |> Enum.map(fn report ->
        with {:ok, activity} <- CommonAPI.update_report_state(report["id"], report["state"]) do
          ModerationLog.insert_log(%{
            action: "report_update",
            actor: admin,
            subject: activity
          })

          activity
        else
          {:error, message} -> %{id: report["id"], error: message}
        end
      end)

    case Enum.any?(result, &Map.has_key?(&1, :error)) do
      true -> json_response(conn, :bad_request, result)
      false -> json_response(conn, :no_content, "")
    end
  end

  def report_notes_create(%{assigns: %{user: user}} = conn, %{
        "id" => report_id,
        "content" => content
      }) do
    with {:ok, _} <- ReportNote.create(user.id, report_id, content) do
      ModerationLog.insert_log(%{
        action: "report_note",
        actor: user,
        subject: Activity.get_by_id(report_id),
        text: content
      })

      json_response(conn, :no_content, "")
    else
      _ -> json_response(conn, :bad_request, "")
    end
  end

  def report_notes_delete(%{assigns: %{user: user}} = conn, %{
        "id" => note_id,
        "report_id" => report_id
      }) do
    with {:ok, note} <- ReportNote.destroy(note_id) do
      ModerationLog.insert_log(%{
        action: "report_note_delete",
        actor: user,
        subject: Activity.get_by_id(report_id),
        text: note.content
      })

      json_response(conn, :no_content, "")
    else
      _ -> json_response(conn, :bad_request, "")
    end
  end

  def status_update(%{assigns: %{user: admin}} = conn, %{"id" => id} = params) do
    with {:ok, activity} <- CommonAPI.update_activity_scope(id, params) do
      {:ok, sensitive} = Ecto.Type.cast(:boolean, params["sensitive"])

      ModerationLog.insert_log(%{
        action: "status_update",
        actor: admin,
        subject: activity,
        sensitive: sensitive,
        visibility: params["visibility"]
      })

      conn
      |> put_view(StatusView)
      |> render("show.json", %{activity: activity})
    end
  end

  def status_delete(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with {:ok, %Activity{}} <- CommonAPI.delete(id, user) do
      ModerationLog.insert_log(%{
        action: "status_delete",
        actor: user,
        subject_id: id
      })

      json(conn, %{})
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

  def migrate_to_db(conn, _params) do
    Mix.Tasks.Pleroma.Config.run(["migrate_to_db"])
    json(conn, %{})
  end

  def migrate_from_db(conn, _params) do
    Mix.Tasks.Pleroma.Config.run(["migrate_from_db", Pleroma.Config.get(:env), "true"])
    json(conn, %{})
  end

  def config_show(conn, _params) do
    configs = Pleroma.Repo.all(Config)

    conn
    |> put_view(ConfigView)
    |> render("index.json", %{configs: configs})
  end

  def config_update(conn, %{"configs" => configs}) do
    updated =
      if Pleroma.Config.get([:instance, :dynamic_configuration]) do
        updated =
          Enum.map(configs, fn
            %{"group" => group, "key" => key, "delete" => "true"} = params ->
              {:ok, config} = Config.delete(%{group: group, key: key, subkeys: params["subkeys"]})
              config

            %{"group" => group, "key" => key, "value" => value} ->
              {:ok, config} = Config.update_or_create(%{group: group, key: key, value: value})
              config
          end)
          |> Enum.reject(&is_nil(&1))

        Pleroma.Config.TransferTask.load_and_update_env()
        Mix.Tasks.Pleroma.Config.run(["migrate_from_db", Pleroma.Config.get(:env), "false"])
        updated
      else
        []
      end

    conn
    |> put_view(ConfigView)
    |> render("index.json", %{configs: updated})
  end

  def reload_emoji(conn, _params) do
    Pleroma.Emoji.reload()

    conn |> json("ok")
  end

  def confirm_email(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames}) do
    users = nicknames |> Enum.map(&User.get_cached_by_nickname/1)

    User.toggle_confirmation(users)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: users,
      action: "confirm_email"
    })

    conn |> json("")
  end

  def resend_confirmation_email(%{assigns: %{user: admin}} = conn, %{"nicknames" => nicknames}) do
    users = nicknames |> Enum.map(&User.get_cached_by_nickname/1)

    User.try_send_confirmation_email(users)

    ModerationLog.insert_log(%{
      actor: admin,
      subject: users,
      action: "resend_confirmation_email"
    })

    conn |> json("")
  end

  def errors(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(dgettext("errors", "Not found"))
  end

  def errors(conn, {:error, reason}) do
    conn
    |> put_status(:bad_request)
    |> json(reason)
  end

  def errors(conn, {:param_cast, _}) do
    conn
    |> put_status(:bad_request)
    |> json(dgettext("errors", "Invalid parameters"))
  end

  def errors(conn, _) do
    conn
    |> put_status(:internal_server_error)
    |> json(dgettext("errors", "Something went wrong"))
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
