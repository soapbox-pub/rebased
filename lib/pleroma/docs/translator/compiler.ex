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
            fn string ->
              quote do
                Pleroma.Web.Gettext.dgettext_noop("config_descriptions", unquote(string))
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
    |> Enum.reduce([], &process_item/2)
  end

  defp process_item(entity, acc) do
    current_level =
      acc
      |> process_desc(entity)
      |> process_label(entity)

    process_children(entity, current_level)
  end

  defp process_desc(acc, %{description: desc}) do
    [desc | acc]
  end

  defp process_desc(acc, _) do
    acc
  end

  defp process_label(acc, %{label: label}) do
    [label | acc]
  end

  defp process_label(acc, _) do
    acc
  end

  defp process_children(%{children: children}, acc) do
    children
    |> Enum.reduce(acc, &process_item/2)
  end

  defp process_children(_, acc) do
    acc
  end
end
