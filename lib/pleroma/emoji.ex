# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emoji do
  @moduledoc """
  This GenServer stores in an ETS table the list of the loaded emojis,
  and also allows to reload the list at runtime.
  """
  use GenServer

  alias Pleroma.Emoji.Combinations
  alias Pleroma.Emoji.Loader

  require Logger

  @ets __MODULE__.Ets
  @ets_options [
    :ordered_set,
    :protected,
    :named_table,
    {:read_concurrency, true}
  ]

  defstruct [:code, :file, :tags, :safe_code, :safe_file]

  @doc "Build emoji struct"
  def build({code, file, tags}) do
    %__MODULE__{
      code: code,
      file: file,
      tags: tags,
      safe_code: Pleroma.HTML.strip_tags(code),
      safe_file: Pleroma.HTML.strip_tags(file)
    }
  end

  def build({code, file}), do: build({code, file, []})

  @doc false
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Reloads the emojis from disk."
  @spec reload() :: :ok
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  @doc "Returns the path of the emoji `name`."
  @spec get(String.t()) :: String.t() | nil
  def get(name) do
    name = maybe_strip_name(name)

    case :ets.lookup(@ets, name) do
      [{_, path}] -> path
      _ -> nil
    end
  end

  @spec exist?(String.t()) :: boolean()
  def exist?(name), do: not is_nil(get(name))

  @doc "Returns all the emojos!!"
  @spec get_all() :: list({String.t(), String.t(), String.t()})
  def get_all do
    :ets.tab2list(@ets)
  end

  @doc "Clear out old emojis"
  def clear_all, do: :ets.delete_all_objects(@ets)

  @doc false
  def init(_) do
    @ets = :ets.new(@ets, @ets_options)
    GenServer.cast(self(), :reload)
    {:ok, nil}
  end

  @doc false
  def handle_cast(:reload, state) do
    update_emojis(Loader.load())
    {:noreply, state}
  end

  @doc false
  def handle_call(:reload, _from, state) do
    update_emojis(Loader.load())
    {:reply, :ok, state}
  end

  @doc false
  def terminate(_, _) do
    :ok
  end

  @doc false
  def code_change(_old_vsn, state, _extra) do
    update_emojis(Loader.load())
    {:ok, state}
  end

  defp update_emojis(emojis) do
    :ets.insert(@ets, emojis)
  end

  @external_resource "lib/pleroma/emoji-test.txt"

  regional_indicators =
    Enum.map(127_462..127_487, fn codepoint ->
      <<codepoint::utf8>>
    end)

  emojis =
    @external_resource
    |> File.read!()
    |> String.split("\n")
    |> Enum.filter(fn line ->
      line != "" and not String.starts_with?(line, "#") and
        String.contains?(line, "fully-qualified")
    end)
    |> Enum.map(fn line ->
      line
      |> String.split(";", parts: 2)
      |> hd()
      |> String.trim()
      |> String.split()
      |> Enum.map(fn codepoint ->
        <<String.to_integer(codepoint, 16)::utf8>>
      end)
      |> Enum.join()
    end)
    |> Enum.uniq()

  emojis = emojis ++ regional_indicators

  for emoji <- emojis do
    def is_unicode_emoji?(unquote(emoji)), do: true
  end

  def is_unicode_emoji?(_), do: false

  @emoji_regex ~r/:[A-Za-z0-9_-]+(@.+)?:/

  def is_custom_emoji?(s) when is_binary(s), do: Regex.match?(@emoji_regex, s)

  def is_custom_emoji?(_), do: false

  def maybe_strip_name(name) when is_binary(name), do: String.trim(name, ":")

  def maybe_strip_name(name), do: name

  def maybe_quote(name) when is_binary(name) do
    if is_unicode_emoji?(name) do
      name
    else
      if String.starts_with?(name, ":") do
        name
      else
        ":#{name}:"
      end
    end
  end

  def maybe_quote(name), do: name

  def emoji_url(%{"type" => "EmojiReact", "content" => _, "tag" => []}), do: nil

  def emoji_url(%{"type" => "EmojiReact", "content" => emoji, "tag" => tags}) do
    emoji = maybe_strip_name(emoji)

    tag =
      tags
      |> Enum.find(fn tag ->
        tag["type"] == "Emoji" && !is_nil(tag["name"]) && tag["name"] == emoji
      end)

    if is_nil(tag) do
      nil
    else
      tag
      |> Map.get("icon")
      |> Map.get("url")
    end
  end

  def emoji_url(_), do: nil

  def emoji_name_with_instance(name, url) do
    url = url |> URI.parse() |> Map.get(:host)
    "#{name}@#{url}"
  end

  emoji_qualification_map =
    emojis
    |> Enum.filter(&String.contains?(&1, "\uFE0F"))
    |> Combinations.variate_emoji_qualification()

  for {qualified, unqualified_list} <- emoji_qualification_map do
    for unqualified <- unqualified_list do
      def fully_qualify_emoji(unquote(unqualified)), do: unquote(qualified)
    end
  end

  def fully_qualify_emoji(emoji), do: emoji
end
