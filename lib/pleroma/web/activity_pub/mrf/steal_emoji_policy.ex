# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.StealEmojiPolicy do
  require Logger

  alias Pleroma.Config

  @moduledoc "Detect new emojis by their shortcode and steals them"
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  defp accept_host?(host), do: host in Config.get([:mrf_steal_emoji, :hosts], [])

  defp steal_emoji({shortcode, url}, emoji_dir_path) do
    url = Pleroma.Web.MediaProxy.url(url)

    with {:ok, %{status: status} = response} when status in 200..299 <- Pleroma.HTTP.get(url) do
      size_limit = Config.get([:mrf_steal_emoji, :size_limit], 50_000)

      if byte_size(response.body) <= size_limit do
        extension =
          url
          |> URI.parse()
          |> Map.get(:path)
          |> Path.basename()
          |> Path.extname()

        file_path = Path.join(emoji_dir_path, shortcode <> (extension || ".png"))

        case File.write(file_path, response.body) do
          :ok ->
            shortcode

          e ->
            Logger.warn("MRF.StealEmojiPolicy: Failed to write to #{file_path}: #{inspect(e)}")
            nil
        end
      else
        Logger.debug(
          "MRF.StealEmojiPolicy: :#{shortcode}: at #{url} (#{byte_size(response.body)} B) over size limit (#{size_limit} B)"
        )

        nil
      end
    else
      e ->
        Logger.warn("MRF.StealEmojiPolicy: Failed to fetch #{url}: #{inspect(e)}")
        nil
    end
  end

  @impl true
  def filter(%{"object" => %{"emoji" => foreign_emojis, "actor" => actor}} = message) do
    host = URI.parse(actor).host

    if host != Pleroma.Web.Endpoint.host() and accept_host?(host) do
      installed_emoji = Pleroma.Emoji.get_all() |> Enum.map(fn {k, _} -> k end)

      emoji_dir_path =
        Config.get(
          [:mrf_steal_emoji, :path],
          Path.join(Config.get([:instance, :static_dir]), "emoji/stolen")
        )

      File.mkdir_p(emoji_dir_path)

      new_emojis =
        foreign_emojis
        |> Enum.reject(fn {shortcode, _url} -> shortcode in installed_emoji end)
        |> Enum.filter(fn {shortcode, _url} ->
          reject_emoji? =
            [:mrf_steal_emoji, :rejected_shortcodes]
            |> Config.get([])
            |> Enum.find(false, fn regex -> String.match?(shortcode, regex) end)

          !reject_emoji?
        end)
        |> Enum.map(&steal_emoji(&1, emoji_dir_path))
        |> Enum.filter(& &1)

      if !Enum.empty?(new_emojis) do
        Logger.info("Stole new emojis: #{inspect(new_emojis)}")
        Pleroma.Emoji.reload()
      end
    end

    {:ok, message}
  end

  def filter(message), do: {:ok, message}

  @impl true
  @spec config_description :: %{
          children: [
            %{
              description: <<_::272, _::_*256>>,
              key: :hosts | :rejected_shortcodes | :size_limit,
              suggestions: [any(), ...],
              type: {:list, :string} | {:list, :string} | :integer
            },
            ...
          ],
          description: <<_::448>>,
          key: :mrf_steal_emoji,
          label: <<_::80>>,
          related_policy: <<_::352>>
        }
  def config_description do
    %{
      key: :mrf_steal_emoji,
      related_policy: "Pleroma.Web.ActivityPub.MRF.StealEmojiPolicy",
      label: "MRF Emojis",
      description: "Steals emojis from selected instances when it sees them.",
      children: [
        %{
          key: :hosts,
          type: {:list, :string},
          description: "List of hosts to steal emojis from",
          suggestions: [""]
        },
        %{
          key: :rejected_shortcodes,
          type: {:list, :string},
          description: "Regex-list of shortcodes to reject",
          suggestions: [""]
        },
        %{
          key: :size_limit,
          type: :integer,
          description: "File size limit (in bytes), checked before an emoji is saved to the disk",
          suggestions: ["100000"]
        }
      ]
    }
  end

  @impl true
  def describe do
    {:ok, %{}}
  end
end
