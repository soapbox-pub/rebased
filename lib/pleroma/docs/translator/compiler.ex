# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Docs.Translator.Compiler do
  @external_resource "config/description.exs"
  @raw_config Pleroma.Config.Loader.read("config/description.exs")
  @raw_descriptions @raw_config[:pleroma][:config_description]

  defmacro __before_compile__(_env) do
    strings =
      __MODULE__.descriptions()
      |> __MODULE__.extract_strings()

    quote do
      def placeholder do
        unquote do
          Enum.map(
            strings,
            fn {path, type, string} ->
              ctxt = msgctxt_for(path, type)

              quote do
                Pleroma.Web.Gettext.dpgettext_noop(
                  "config_descriptions",
                  unquote(ctxt),
                  unquote(string)
                )
              end
            end
          )
        end
      end
    end
  end

  def descriptions do
    Pleroma.Web.ActivityPub.MRF.config_descriptions()
    |> Enum.reduce(@raw_descriptions, fn description, acc -> [description | acc] end)
    |> Pleroma.Docs.Generator.convert_to_strings()
  end

  def extract_strings(descriptions) do
    descriptions
    |> Enum.reduce(%{strings: [], path: []}, &process_item/2)
    |> Map.get(:strings)
  end

  defp process_item(entity, acc) do
    current_level =
      acc
      |> process_desc(entity)
      |> process_label(entity)

    process_children(entity, current_level)
  end

  defp process_desc(acc, %{description: desc} = item) do
    %{
      strings: [{acc.path ++ [key_for(item)], "description", desc} | acc.strings],
      path: acc.path
    }
  end

  defp process_desc(acc, _) do
    acc
  end

  defp process_label(acc, %{label: label} = item) do
    %{
      strings: [{acc.path ++ [key_for(item)], "label", label} | acc.strings],
      path: acc.path
    }
  end

  defp process_label(acc, _) do
    acc
  end

  defp process_children(%{children: children} = item, acc) do
    current_level = Map.put(acc, :path, acc.path ++ [key_for(item)])

    children
    |> Enum.reduce(current_level, &process_item/2)
    |> Map.put(:path, acc.path)
  end

  defp process_children(_, acc) do
    acc
  end

  def msgctxt_for(path, type) do
    "config #{type} at #{Enum.join(path, " > ")}"
  end

  defp convert_group({_, group}) do
    group
  end

  defp convert_group(group) do
    group
  end

  def key_for(%{group: group, key: key}) do
    "#{convert_group(group)}-#{key}"
  end

  def key_for(%{group: group}) do
    convert_group(group)
  end

  def key_for(%{key: key}) do
    key
  end

  def key_for(_) do
    nil
  end
end
