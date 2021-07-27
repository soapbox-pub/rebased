# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AccountView do
  use Pleroma.Web, :view

  alias Pleroma.User
  alias Pleroma.Web.AdminAPI
  alias Pleroma.Web.AdminAPI.AccountView
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI
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
      :is_locked,
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
      :is_discoverable,
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
      "email" => user.email,
      "avatar" => avatar,
      "nickname" => user.nickname,
      "display_name" => display_name,
      "is_active" => user.is_active,
      "local" => user.local,
      "roles" => roles(user),
      "tags" => user.tags || [],
      "is_confirmed" => user.is_confirmed,
      "is_approved" => user.is_approved,
      "url" => user.uri || user.ap_id,
      "registration_reason" => user.registration_reason,
      "actor_type" => user.actor_type,
      "created_at" => CommonAPI.Utils.to_masto_date(user.inserted_at)
    }
  end

  def render("created_many.json", %{users: users}) do
    render_many(users, AccountView, "created.json", as: :user)
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

  def render("create_errors.json", %{changesets: changesets}) do
    render_many(changesets, AccountView, "create_error.json", as: :changeset)
  end

  def render("create_error.json", %{changeset: %Ecto.Changeset{changes: changes, errors: errors}}) do
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

  def merge_account_views(%User{} = user) do
    MastodonAPI.AccountView.render("show.json", %{user: user, skip_visibility_check: true})
    |> Map.merge(AdminAPI.AccountView.render("show.json", %{user: user}))
  end

  def merge_account_views(_), do: %{}

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

  defp roles(%{is_moderator: is_moderator, is_admin: is_admin}) do
    %{
      admin: is_admin,
      moderator: is_moderator
    }
  end
end
