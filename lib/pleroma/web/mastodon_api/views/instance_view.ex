# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.InstanceView do
  use Pleroma.Web, :view

  alias Pleroma.Config
  alias Pleroma.Web.ActivityPub.MRF

  @mastodon_api_level "2.7.2"

  def render("show.json", _) do
    instance = Config.get(:instance)

    %{
      uri: Pleroma.Web.Endpoint.url(),
      title: Keyword.get(instance, :name),
      description: Keyword.get(instance, :description),
      version: "#{@mastodon_api_level} (compatible; #{Pleroma.Application.named_version()})",
      email: Keyword.get(instance, :email),
      urls: %{
        streaming_api: Pleroma.Web.Endpoint.websocket_url()
      },
      stats: Pleroma.Stats.get_stats(),
      thumbnail:
        URI.merge(Pleroma.Web.Endpoint.url(), Keyword.get(instance, :instance_thumbnail))
        |> to_string,
      languages: ["en"],
      registrations: Keyword.get(instance, :registrations_open),
      approval_required: Keyword.get(instance, :account_approval_required),
      # Extra (not present in Mastodon):
      max_toot_chars: Keyword.get(instance, :limit),
      max_media_attachments: Keyword.get(instance, :max_media_attachments),
      poll_limits: Keyword.get(instance, :poll_limits),
      upload_limit: Keyword.get(instance, :upload_limit),
      avatar_upload_limit: Keyword.get(instance, :avatar_upload_limit),
      background_upload_limit: Keyword.get(instance, :background_upload_limit),
      banner_upload_limit: Keyword.get(instance, :banner_upload_limit),
      background_image: Pleroma.Web.Endpoint.url() <> Keyword.get(instance, :background_image),
      shout_limit: Config.get([:shout, :limit]),
      description_limit: Keyword.get(instance, :description_limit),
      rules: render(__MODULE__, "rules.json"),
      pleroma: %{
        metadata: %{
          account_activation_required: Keyword.get(instance, :account_activation_required),
          features: features(),
          federation: federation(),
          fields_limits: fields_limits(),
          post_formats: Config.get([:instance, :allowed_post_formats]),
          privileged_staff: Config.get([:instance, :privileged_staff]),
          birthday_required: Config.get([:instance, :birthday_required]),
          birthday_min_age: Config.get([:instance, :birthday_min_age])
        },
        stats: %{mau: Pleroma.User.active_user_count()},
        vapid_public_key: Keyword.get(Pleroma.Web.Push.vapid_config(), :public_key)
      }
    }
  end

  def render("rules.json", _) do
    Pleroma.Rule.query()
    |> Pleroma.Repo.all()
    |> render_many(__MODULE__, "rule.json", as: :rule)
  end

  def render("rule.json", %{rule: rule}) do
    %{
      id: rule.id,
      text: rule.text
    }
  end

  def features do
    [
      "pleroma_api",
      "mastodon_api",
      "mastodon_api_streaming",
      "polls",
      "v2_suggestions",
      "pleroma_explicit_addressing",
      "shareable_emoji_packs",
      "multifetch",
      "pleroma:api/v1/notifications:include_types_filter",
      if Config.get([:activitypub, :blockers_visible]) do
        "blockers_visible"
      end,
      if Config.get([:media_proxy, :enabled]) do
        "media_proxy"
      end,
      if Config.get([:gopher, :enabled]) do
        "gopher"
      end,
      # backwards compat
      if Config.get([:shout, :enabled]) do
        "chat"
      end,
      if Config.get([:shout, :enabled]) do
        "shout"
      end,
      if Config.get([:instance, :allow_relay]) do
        "relay"
      end,
      if Config.get([:instance, :safe_dm_mentions]) do
        "safe_dm_mentions"
      end,
      "pleroma_emoji_reactions",
      "pleroma_chat_messages",
      if Config.get([:instance, :show_reactions]) do
        "exposable_reactions"
      end,
      if Config.get([:instance, :profile_directory]) do
        "profile_directory"
      end
    ]
    |> Enum.filter(& &1)
  end

  def federation do
    quarantined = Config.get([:instance, :quarantined_instances], [])

    if Config.get([:mrf, :transparency]) do
      {:ok, data} = MRF.describe()

      data
      |> Map.put(
        :quarantined_instances,
        Enum.map(quarantined, fn {instance, _reason} -> instance end)
      )
      # This is for backwards compatibility. We originally didn't sent
      # extra info like a reason why an instance was rejected/quarantined/etc.
      # Because we didn't want to break backwards compatibility it was decided
      # to add an extra "info" key.
      |> Map.put(:quarantined_instances_info, %{
        "quarantined_instances" =>
          quarantined
          |> Enum.map(fn {instance, reason} -> {instance, %{"reason" => reason}} end)
          |> Map.new()
      })
    else
      %{}
    end
    |> Map.put(:enabled, Config.get([:instance, :federating]))
  end

  def fields_limits do
    %{
      max_fields: Config.get([:instance, :max_account_fields]),
      max_remote_fields: Config.get([:instance, :max_remote_account_fields]),
      name_length: Config.get([:instance, :account_field_name_length]),
      value_length: Config.get([:instance, :account_field_value_length])
    }
  end
end
