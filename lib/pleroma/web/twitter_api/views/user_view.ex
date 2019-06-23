# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.UserView do
  use Pleroma.Web, :view
  alias Pleroma.Formatter
  alias Pleroma.HTML
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MediaProxy

  def render("show.json", %{user: user = %User{}} = assigns) do
    render_one(user, Pleroma.Web.TwitterAPI.UserView, "user.json", assigns)
  end

  def render("index.json", %{users: users, for: user}) do
    users
    |> render_many(Pleroma.Web.TwitterAPI.UserView, "user.json", for: user)
    |> Enum.filter(&Enum.any?/1)
  end

  def render("user.json", %{user: user = %User{}} = assigns) do
    if User.visible_for?(user, assigns[:for]),
      do: do_render("user.json", assigns),
      else: %{}
  end

  def render("short.json", %{
        user: %User{
          nickname: nickname,
          id: id,
          ap_id: ap_id,
          name: name
        }
      }) do
    %{
      "fullname" => name,
      "id" => id,
      "ostatus_uri" => ap_id,
      "profile_url" => ap_id,
      "screen_name" => nickname
    }
  end

  defp do_render("user.json", %{user: user = %User{}} = assigns) do
    for_user = assigns[:for]
    image = User.avatar_url(user) |> MediaProxy.url()

    {following, follows_you, statusnet_blocking} =
      if for_user do
        {
          User.following?(for_user, user),
          User.following?(user, for_user),
          User.blocks?(for_user, user)
        }
      else
        {false, false, false}
      end

    user_info = User.get_cached_user_info(user)

    emoji =
      (user.info.source_data["tag"] || [])
      |> Enum.filter(fn %{"type" => t} -> t == "Emoji" end)
      |> Enum.map(fn %{"icon" => %{"url" => url}, "name" => name} ->
        {String.trim(name, ":"), url}
      end)

    emoji = Enum.dedup(emoji ++ user.info.emoji)

    description_html =
      (user.bio || "")
      |> HTML.filter_tags(User.html_filter_policy(for_user))
      |> Formatter.emojify(emoji)

    # ``fields`` is an array of mastodon profile field, containing ``{"name": "…", "value": "…"}``.
    # For example: [{"name": "Pronoun", "value": "she/her"}, …]
    fields =
      (user.info.source_data["attachment"] || [])
      |> Enum.filter(fn %{"type" => t} -> t == "PropertyValue" end)
      |> Enum.map(fn fields -> Map.take(fields, ["name", "value"]) end)

    data =
      %{
        "created_at" => user.inserted_at |> Utils.format_naive_asctime(),
        "description" => HTML.strip_tags((user.bio || "") |> String.replace("<br>", "\n")),
        "description_html" => description_html,
        "favourites_count" => 0,
        "followers_count" => user_info[:follower_count],
        "following" => following,
        "follows_you" => follows_you,
        "statusnet_blocking" => statusnet_blocking,
        "friends_count" => user_info[:following_count],
        "id" => user.id,
        "name" => user.name || user.nickname,
        "name_html" =>
          if(user.name,
            do: HTML.strip_tags(user.name) |> Formatter.emojify(emoji),
            else: user.nickname
          ),
        "profile_image_url" => image,
        "profile_image_url_https" => image,
        "profile_image_url_profile_size" => image,
        "profile_image_url_original" => image,
        "screen_name" => user.nickname,
        "statuses_count" => user_info[:note_count],
        "statusnet_profile_url" => user.ap_id,
        "cover_photo" => User.banner_url(user) |> MediaProxy.url(),
        "background_image" => image_url(user.info.background) |> MediaProxy.url(),
        "is_local" => user.local,
        "locked" => user.info.locked,
        "hide_followers" => user.info.hide_followers,
        "hide_follows" => user.info.hide_follows,
        "fields" => fields,

        # Pleroma extension
        "pleroma" =>
          %{
            "confirmation_pending" => user_info.confirmation_pending,
            "tags" => user.tags,
            "skip_thread_containment" => user.info.skip_thread_containment
          }
          |> maybe_with_activation_status(user, for_user)
          |> with_notification_settings(user, for_user)
      }
      |> maybe_with_user_settings(user, for_user)
      |> maybe_with_role(user, for_user)

    if assigns[:token] do
      Map.put(data, "token", token_string(assigns[:token]))
    else
      data
    end
  end

  defp with_notification_settings(data, %User{id: user_id} = user, %User{id: user_id}) do
    Map.put(data, "notification_settings", user.info.notification_settings)
  end

  defp with_notification_settings(data, _, _), do: data

  defp maybe_with_activation_status(data, user, %User{info: %{is_admin: true}}) do
    Map.put(data, "deactivated", user.info.deactivated)
  end

  defp maybe_with_activation_status(data, _, _), do: data

  defp maybe_with_role(data, %User{id: id} = user, %User{id: id}) do
    Map.merge(data, %{
      "role" => role(user),
      "show_role" => user.info.show_role,
      "rights" => %{
        "delete_others_notice" => !!user.info.is_moderator,
        "admin" => !!user.info.is_admin
      }
    })
  end

  defp maybe_with_role(data, %User{info: %{show_role: true}} = user, _user) do
    Map.merge(data, %{
      "role" => role(user),
      "rights" => %{
        "delete_others_notice" => !!user.info.is_moderator,
        "admin" => !!user.info.is_admin
      }
    })
  end

  defp maybe_with_role(data, _, _), do: data

  defp maybe_with_user_settings(data, %User{info: info, id: id} = _user, %User{id: id}) do
    data
    |> Kernel.put_in(["default_scope"], info.default_scope)
    |> Kernel.put_in(["no_rich_text"], info.no_rich_text)
  end

  defp maybe_with_user_settings(data, _, _), do: data
  defp role(%User{info: %{:is_admin => true}}), do: "admin"
  defp role(%User{info: %{:is_moderator => true}}), do: "moderator"
  defp role(_), do: "member"

  defp image_url(%{"url" => [%{"href" => href} | _]}), do: href
  defp image_url(_), do: nil

  defp token_string(%Pleroma.Web.OAuth.Token{token: token_str}), do: token_str
  defp token_string(token), do: token
end
