# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AccountView do
  use Pleroma.Web, :view

  alias Pleroma.User
  alias Pleroma.Web.AdminAPI.AccountView
  alias Pleroma.Web.MediaProxy

  def render("index.json", %{users: users, count: count, page_size: page_size}) do
    %{
      users: render_many(users, AccountView, "show.json", as: :user),
      count: count,
      page_size: page_size
    }
  end

  def render("index.json", %{users: users}) do
    %{
      users: render_many(users, AccountView, "show.json", as: :user)
    }
  end

  def render("credentials.json", %{user: user, for: for_user}) do
    user = User.sanitize_html(user, User.html_filter_policy(for_user))
    avatar = User.avatar_url(user) |> MediaProxy.url()
    banner = User.banner_url(user) |> MediaProxy.url()
    background = image_url(user.background) |> MediaProxy.url()

    user
    |> Map.take([
      :id,
      :bio,
      :email,
      :fields,
      :name,
      :nickname,
      :locked,
      :no_rich_text,
      :default_scope,
      :hide_follows,
      :hide_followers_count,
      :hide_follows_count,
      :hide_followers,
      :hide_favorites,
      :allow_following_move,
      :show_role,
      :skip_thread_containment,
      :pleroma_settings_store,
      :raw_fields,
      :discoverable,
      :actor_type
    ])
    |> Map.merge(%{
      "avatar" => avatar,
      "banner" => banner,
      "background" => background
    })
  end

  def render("show.json", %{user: user}) do
    avatar = User.avatar_url(user) |> MediaProxy.url()
    display_name = Pleroma.HTML.strip_tags(user.name || user.nickname)
    user = User.sanitize_html(user, FastSanitize.Sanitizer.StripTags)

    %{
      "id" => user.id,
      "avatar" => avatar,
      "nickname" => user.nickname,
      "display_name" => display_name,
      "deactivated" => user.deactivated,
      "local" => user.local,
      "roles" => User.roles(user),
      "tags" => user.tags || [],
      "confirmation_pending" => user.confirmation_pending
    }
  end

  def render("invite.json", %{invite: invite}) do
    %{
      "id" => invite.id,
      "token" => invite.token,
      "used" => invite.used,
      "expires_at" => invite.expires_at,
      "uses" => invite.uses,
      "max_use" => invite.max_use,
      "invite_type" => invite.invite_type
    }
  end

  def render("invites.json", %{invites: invites}) do
    %{
      invites: render_many(invites, AccountView, "invite.json", as: :invite)
    }
  end

  def render("created.json", %{user: user}) do
    %{
      type: "success",
      code: 200,
      data: %{
        nickname: user.nickname,
        email: user.email
      }
    }
  end

  def render("create-error.json", %{changeset: %Ecto.Changeset{changes: changes, errors: errors}}) do
    %{
      type: "error",
      code: 409,
      error: parse_error(errors),
      data: %{
        nickname: Map.get(changes, :nickname),
        email: Map.get(changes, :email)
      }
    }
  end

  defp parse_error([]), do: ""

  defp parse_error(errors) do
    ## when nickname is duplicate ap_id constraint error is raised
    nickname_error = Keyword.get(errors, :nickname) || Keyword.get(errors, :ap_id)
    email_error = Keyword.get(errors, :email)
    password_error = Keyword.get(errors, :password)

    cond do
      nickname_error ->
        "nickname #{elem(nickname_error, 0)}"

      email_error ->
        "email #{elem(email_error, 0)}"

      password_error ->
        "password #{elem(password_error, 0)}"

      true ->
        ""
    end
  end

  defp image_url(%{"url" => [%{"href" => href} | _]}), do: href
  defp image_url(_), do: nil
end
