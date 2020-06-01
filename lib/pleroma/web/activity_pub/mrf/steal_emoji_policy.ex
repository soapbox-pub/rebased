# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.StealEmojiPolicy do
  require Logger

  alias Pleroma.Config

  @moduledoc "Detect new emojis by their shortcode and steals them"
  @behaviour Pleroma.Web.ActivityPub.MRF

  defp remote_host?(host), do: host != Config.get([Pleroma.Web.Endpoint, :url, :host])

  defp accept_host?(host), do: host in Config.get([:mrf_steal_emoji, :hosts], [])

  defp steal_emoji({shortcode, url}) do
    url = Pleroma.Web.MediaProxy.url(url)
    {:ok, response} = Pleroma.HTTP.get(url)
    size_limit = Config.get([:mrf_steal_emoji, :size_limit], 50_000)

    if byte_size(response.body) <= size_limit do
      emoji_dir_path =
        Config.get(
          [:mrf_steal_emoji, :path],
          Path.join(Config.get([:instance, :static_dir]), "emoji/stolen")
        )

      extension =
        url
        |> URI.parse()
        |> Map.get(:path)
        |> Path.basename()
        |> Path.extname()

      file_path = Path.join([emoji_dir_path, shortcode <> (extension || ".png")])

      try do
        :ok = File.write(file_path, response.body)

        shortcode
      rescue
        e ->
          Logger.warn("MRF.StealEmojiPolicy: Failed to write to #{file_path}: #{inspect(e)}")
          nil
      end
    else
      Logger.debug(
        "MRF.StealEmojiPolicy: :#{shortcode}: at #{url} (#{byte_size(response.body)} B) over size limit (#{
          size_limit
        } B)"
      )

      nil
    end
  rescue
    e ->
      Logger.warn("MRF.StealEmojiPolicy: Failed to fetch #{url}: #{inspect(e)}")
      nil
  end

  @impl true
  def filter(%{"object" => %{"emoji" => foreign_emojis, "actor" => actor}} = message) do
    host = URI.parse(actor).host

    if remote_host?(host) and accept_host?(host) do
      installed_emoji = Pleroma.Emoji.get_all() |> Enum.map(fn {k, _} -> k end)

      new_emojis =
        foreign_emojis
        |> Enum.filter(fn {shortcode, _url} -> shortcode not in installed_emoji end)
        |> Enum.filter(fn {shortcode, _url} ->
          reject_emoji? =
            Config.get([:mrf_steal_emoji, :rejected_shortcodes], [])
            |> Enum.find(false, fn regex -> String.match?(shortcode, regex) end)

          !reject_emoji?
        end)
        |> Enum.map(&steal_emoji(&1))
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
  def describe do
    {:ok, %{}}
  end
end
