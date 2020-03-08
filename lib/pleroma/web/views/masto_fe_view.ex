# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastoFEView do
  use Pleroma.Web, :view
  alias Pleroma.Config
  alias Pleroma.User
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.CustomEmojiView

  @default_settings %{
    onboarded: true,
    home: %{
      shows: %{
        reblog: true,
        reply: true
      }
    },
    notifications: %{
      alerts: %{
        follow: true,
        favourite: true,
        reblog: true,
        mention: true
      },
      shows: %{
        follow: true,
        favourite: true,
        reblog: true,
        mention: true
      },
      sounds: %{
        follow: true,
        favourite: true,
        reblog: true,
        mention: true
      }
    }
  }

  def initial_state(token, user, custom_emojis) do
    limit = Config.get([:instance, :limit])

    %{
      meta: %{
        streaming_api_base_url: Pleroma.Web.Endpoint.websocket_url(),
        access_token: token,
        locale: "en",
        domain: Pleroma.Web.Endpoint.host(),
        admin: "1",
        me: "#{user.id}",
        unfollow_modal: false,
        boost_modal: false,
        delete_modal: true,
        auto_play_gif: false,
        display_sensitive_media: false,
        reduce_motion: false,
        max_toot_chars: limit,
        mascot: User.get_mascot(user)["url"]
      },
      poll_limits: Config.get([:instance, :poll_limits]),
      rights: %{
        delete_others_notice: present?(user.is_moderator),
        admin: present?(user.is_admin)
      },
      compose: %{
        me: "#{user.id}",
        default_privacy: user.default_scope,
        default_sensitive: false,
        allow_content_types: Config.get([:instance, :allowed_post_formats])
      },
      media_attachments: %{
        accept_content_types: [
          ".jpg",
          ".jpeg",
          ".png",
          ".gif",
          ".webm",
          ".mp4",
          ".m4v",
          "image\/jpeg",
          "image\/png",
          "image\/gif",
          "video\/webm",
          "video\/mp4"
        ]
      },
      settings: user.settings || @default_settings,
      push_subscription: nil,
      accounts: %{user.id => render(AccountView, "show.json", user: user, for: user)},
      custom_emojis: render(CustomEmojiView, "index.json", custom_emojis: custom_emojis),
      char_limit: limit
    }
    |> Jason.encode!()
    |> Phoenix.HTML.raw()
  end

  defp present?(nil), do: false
  defp present?(false), do: false
  defp present?(_), do: true

  def render("manifest.json", _params) do
    %{
      name: Config.get([:instance, :name]),
      description: Config.get([:instance, :description]),
      icons: Config.get([:manifest, :icons]),
      theme_color: Config.get([:manifest, :theme_color]),
      background_color: Config.get([:manifest, :background_color]),
      display: "standalone",
      scope: Pleroma.Web.base_url(),
      start_url: masto_fe_path(Pleroma.Web.Endpoint, :index, ["getting-started"]),
      categories: [
        "social"
      ],
      serviceworker: %{
        src: "/sw.js"
      }
    }
  end
end
