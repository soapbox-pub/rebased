# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.InstanceView do
  use Pleroma.Web, :view

  alias Pleroma.Config
  alias Pleroma.Domain
  alias Pleroma.Web.ActivityPub.MRF
  alias Pleroma.Web.AdminAPI.DomainView

  @mastodon_api_level "2.7.2"

  @block_severities %{
    federated_timeline_removal: "silence",
    reject: "suspend"
  }

  def render("show.json", _) do
    instance = Config.get(:instance)

    common_information(instance)
    |> Map.merge(%{
      uri: Pleroma.Web.WebFinger.host(),
      description: Keyword.get(instance, :description),
      short_description: Keyword.get(instance, :short_description),
      email: Keyword.get(instance, :email),
      urls: %{
        streaming_api: Pleroma.Web.Endpoint.websocket_url()
      },
      stats: Pleroma.Stats.get_stats(),
      thumbnail:
        URI.merge(Pleroma.Web.Endpoint.url(), Keyword.get(instance, :instance_thumbnail))
        |> to_string,
      registrations: Keyword.get(instance, :registrations_open),
      approval_required: Keyword.get(instance, :account_approval_required),
      contact_account: contact_account(Keyword.get(instance, :contact_username)),
      configuration: configuration(),
      rules: render(__MODULE__, "rules.json"),
      # Extra (not present in Mastodon):
      max_toot_chars: Keyword.get(instance, :limit),
      max_media_attachments: Keyword.get(instance, :max_media_attachments),
      poll_limits: Keyword.get(instance, :poll_limits),
      upload_limit: Keyword.get(instance, :upload_limit),
      avatar_upload_limit: Keyword.get(instance, :avatar_upload_limit),
      background_upload_limit: Keyword.get(instance, :background_upload_limit),
      banner_upload_limit: Keyword.get(instance, :banner_upload_limit),
      background_image: Pleroma.Web.Endpoint.url() <> Keyword.get(instance, :background_image),
      description_limit: Keyword.get(instance, :description_limit),
      chat_limit: Keyword.get(instance, :chat_limit),
      pleroma: pleroma_configuration(instance)
    })
  end

  def render("show2.json", _) do
    instance = Config.get(:instance)

    common_information(instance)
    |> Map.merge(%{
      domain: Pleroma.Web.WebFinger.host(),
      source_url: Pleroma.Application.repository(),
      description: Keyword.get(instance, :short_description),
      usage: %{users: %{active_month: Pleroma.User.active_user_count()}},
      thumbnail: %{
        url:
          URI.merge(Pleroma.Web.Endpoint.url(), Keyword.get(instance, :instance_thumbnail))
          |> to_string
      },
      configuration: configuration2(),
      registrations: %{
        enabled: Keyword.get(instance, :registrations_open),
        approval_required: Keyword.get(instance, :account_approval_required),
        message: nil,
        url: nil
      },
      contact: %{
        email: Keyword.get(instance, :email),
        account: contact_account(Keyword.get(instance, :contact_username))
      },
      # Extra (not present in Mastodon):
      pleroma: pleroma_configuration2(instance)
    })
  end

  def render("rules.json", _) do
    Pleroma.Rule.query()
    |> Pleroma.Repo.all()
    |> render_many(__MODULE__, "rule.json", as: :rule)
  end

  def render("rule.json", %{rule: rule}) do
    %{
      id: to_string(rule.id),
      text: rule.text,
      hint: rule.hint || ""
    }
  end

  def render("domain_blocks.json", _) do
    if Config.get([:mrf, :transparency]) do
      exclusions = Config.get([:mrf, :transparency_exclusions]) |> MRF.instance_list_from_tuples()

      domain_blocks =
        Config.get(:mrf_simple)
        |> Enum.map(fn {rule, instances} ->
          MRF.normalize_instance_list(instances)
          |> Enum.reject(fn {host, _} ->
            host in exclusions or not Map.has_key?(@block_severities, rule)
          end)
          |> Enum.map(fn {host, reason} ->
            %{
              domain: host,
              digest: :crypto.hash(:sha256, host) |> Base.encode16(case: :lower),
              severity: Map.get(@block_severities, rule),
              comment: reason
            }
          end)
        end)
        |> List.flatten()

      domain_blocks
    else
      []
    end
  end

  def render("translation_languages.json", _) do
    with true <- Pleroma.Language.Translation.configured?(),
         {:ok, languages} <- Pleroma.Language.Translation.languages_matrix() do
      languages
    else
      _ -> %{}
    end
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
      "editing",
      "quote_posting",
      if Config.get([:activitypub, :blockers_visible]) do
        "blockers_visible"
      end,
      if Config.get([:media_proxy, :enabled]) do
        "media_proxy"
      end,
      if Config.get([:gopher, :enabled]) do
        "gopher"
      end,
      if Config.get([:instance, :allow_relay]) do
        "relay"
      end,
      if Config.get([:instance, :safe_dm_mentions]) do
        "safe_dm_mentions"
      end,
      "pleroma_emoji_reactions",
      "pleroma_custom_emoji_reactions",
      "pleroma_chat_messages",
      if Config.get([:instance, :show_reactions]) do
        "exposable_reactions"
      end,
      if Config.get([:instance, :profile_directory]) do
        "profile_directory"
      end,
      "pleroma:get:main/ostatus",
      "pleroma:group_actors",
      "pleroma:bookmark_folders",
      if Pleroma.Language.Translation.configured?() do
        "translation"
      end,
      "events",
      "multitenancy"
    ]
    |> Enum.filter(& &1)
  end

  defp common_information(instance) do
    %{
      languages: Keyword.get(instance, :languages, ["en"]),
      rules: render(__MODULE__, "rules.json"),
      title: Keyword.get(instance, :name),
      version: "#{@mastodon_api_level} (compatible; #{Pleroma.Application.compat_version()})"
    }
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

  defp fields_limits do
    %{
      max_fields: Config.get([:instance, :max_account_fields]),
      max_remote_fields: Config.get([:instance, :max_remote_account_fields]),
      name_length: Config.get([:instance, :account_field_name_length]),
      value_length: Config.get([:instance, :account_field_value_length])
    }
  end

  defp contact_account(nil), do: nil

  defp contact_account("@" <> username) do
    contact_account(username)
  end

  defp contact_account(username) do
    user = Pleroma.User.get_cached_by_nickname(username)

    if user do
      Pleroma.Web.MastodonAPI.AccountView.render("show.json", %{user: user, for: nil})
    else
      nil
    end
  end

  defp configuration do
    %{
      accounts: %{
        max_featured_tags: 0
      },
      statuses: %{
        max_characters: Config.get([:instance, :limit]),
        max_media_attachments: Config.get([:instance, :max_media_attachments])
      },
      media_attachments: %{
        image_size_limit: Config.get([:instance, :upload_limit]),
        video_size_limit: Config.get([:instance, :upload_limit]),
        supported_mime_types: ["application/octet-stream"]
      },
      polls: %{
        max_options: Config.get([:instance, :poll_limits, :max_options]),
        max_characters_per_option: Config.get([:instance, :poll_limits, :max_option_chars]),
        min_expiration: Config.get([:instance, :poll_limits, :min_expiration]),
        max_expiration: Config.get([:instance, :poll_limits, :max_expiration])
      }
    }
  end

  defp configuration2 do
    configuration()
    |> put_in([:accounts, :max_pinned_statuses], Config.get([:instance, :max_pinned_statuses], 0))
    |> put_in([:statuses, :characters_reserved_per_url], 0)
    |> Map.merge(%{
      translation: %{enabled: Pleroma.Language.Translation.configured?()},
      urls: %{
        streaming: Pleroma.Web.Endpoint.websocket_url(),
        status: Config.get([:instance, :status_page])
      },
      vapid: %{
        public_key: Keyword.get(Pleroma.Web.Push.vapid_config(), :public_key)
      }
    })
  end

  defp restrict_unauthenticated do
    Config.get([:restrict_unauthenticated])
    |> Enum.map(fn {category, features} ->
      features =
        Enum.map(features, fn
          {feature, is_enabled} when is_boolean(is_enabled) -> {feature, is_enabled}
          {feature, :if_instance_is_private} -> {feature, !Config.get!([:instance, :public])}
        end)
        |> Enum.into(%{})

      {category, features}
    end)
    |> Enum.into(%{})
  end

  defp pleroma_configuration(instance) do
    %{
      metadata: %{
        account_activation_required: Keyword.get(instance, :account_activation_required),
        features: features(),
        federation: federation(),
        fields_limits: fields_limits(),
        post_formats: Config.get([:instance, :allowed_post_formats]),
        privileged_staff: Config.get([:instance, :privileged_staff]),
        birthday_required: Config.get([:instance, :birthday_required]),
        birthday_min_age: Config.get([:instance, :birthday_min_age]),
        migration_cooldown_period: Config.get([:instance, :migration_cooldown_period]),
        restrict_unauthenticated: restrict_unauthenticated(),
        translation: translation_configuration(),
        markup: markup(),
        multitenancy: multitenancy()
      },
      stats: %{mau: Pleroma.User.active_user_count()},
      vapid_public_key: Keyword.get(Pleroma.Web.Push.vapid_config(), :public_key),
      oauth_consumer_strategies: Pleroma.Config.oauth_consumer_strategies(),
      favicon:
        URI.merge(Pleroma.Web.Endpoint.url(), Keyword.get(instance, :favicon))
        |> to_string
    }
  end

  defp pleroma_configuration2(instance) do
    configuration = pleroma_configuration(instance)

    configuration
    |> Map.merge(%{
      metadata:
        configuration.metadata
        |> Map.merge(%{
          avatar_upload_limit: Keyword.get(instance, :avatar_upload_limit),
          background_upload_limit: Keyword.get(instance, :background_upload_limit),
          banner_upload_limit: Keyword.get(instance, :banner_upload_limit),
          background_image:
            Pleroma.Web.Endpoint.url() <> Keyword.get(instance, :background_image),
          chat_limit: Keyword.get(instance, :chat_limit),
          description_limit: Keyword.get(instance, :description_limit)
        })
    })
  end

  defp translation_configuration do
    enabled = Pleroma.Language.Translation.configured?()

    source_languages =
      with true <- enabled,
           {:ok, languages} <- Pleroma.Language.Translation.supported_languages(:source) do
        languages
      else
        _ -> nil
      end

    target_languages =
      with true <- enabled,
           {:ok, languages} <- Pleroma.Language.Translation.supported_languages(:target) do
        languages
      else
        _ -> nil
      end

    %{
      source_languages: source_languages,
      target_languages: target_languages,
      allow_unauthenticated: Config.get([Pleroma.Language.Translation, :allow_unauthenticated]),
      allow_remote: Config.get([Pleroma.Language.Translation, :allow_remote])
    }
  end

  defp markup do
    %{
      allow_inline_images: Config.get([:markup, :allow_inline_images]),
      allow_headings: Config.get([:markup, :allow_headings]),
      allow_tables: Config.get([:markup, :allow_tables])
    }
  end

  defp multitenancy do
    enabled = Config.get([:instance, :multitenancy, :enabled])

    if enabled do
      domains =
        [%Domain{id: "", domain: Pleroma.Web.WebFinger.host(), public: true}] ++
          Domain.cached_list()

      %{
        enabled: true,
        domains: DomainView.render("index.json", domains: domains, admin: false)
      }
    else
      nil
    end
  end
end
