# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Utils.Colors do
  alias Pleroma.Web.Utils.Colors.RGB

  # Adapted from:
  # https://gitlab.com/soapbox-pub/soapbox/-/blob/develop/app/soapbox/utils/colors.ts
  @intensity_map %{
    50 => 0.95,
    100 => 0.9,
    200 => 0.75,
    300 => 0.3,
    400 => 0.2,
    600 => 0.9,
    700 => 0.75,
    800 => 0.3,
    900 => 0.19
  }

  def get_shades(base_color, overrides \\ %{})

  def get_shades("#" <> base_color, overrides) do
    base_color = base_color |> hex_to_rgb()

    shades = %{
      500 => base_color |> rgb_to_string()
    }

    shades =
      [50, 100, 200, 300, 400]
      |> Enum.reduce(shades, fn level, map ->
        Map.put(
          map,
          level,
          get_override(level, overrides) || lighten(base_color, Map.get(@intensity_map, level))
        )
      end)

    shades =
      [600, 700, 800, 900]
      |> Enum.reduce(shades, fn level, map ->
        Map.put(
          map,
          level,
          get_override(level, overrides) || darken(base_color, Map.get(@intensity_map, level))
        )
      end)

    shades
  end

  def get_shades(_, overrides), do: get_shades("#0482d8", overrides)

  defp get_override(level, overrides) do
    if Map.has_key?(overrides, "#{level}") do
      Map.get(overrides, "#{level}")
      |> hex_to_rgb()
      |> rgb_to_string()
    end
  end

  defp lighten(%RGB{red: red, green: green, blue: blue}, intensity) do
    %RGB{
      red: round(red + (255 - red) * intensity),
      green: round(green + (255 - green) * intensity),
      blue: round(blue + (255 - blue) * intensity)
    }
    |> rgb_to_string()
  end

  defp darken(%RGB{red: red, green: green, blue: blue}, intensity) do
    %RGB{
      red: round(red * intensity),
      green: round(green * intensity),
      blue: round(blue * intensity)
    }
    |> rgb_to_string()
  end

  defp rgb_to_string(%RGB{red: red, green: green, blue: blue}) do
    "#{red}, #{green}, #{blue}"
  end

  defp hex_to_rgb(<<red::binary-size(2), green::binary-size(2), blue::binary-size(2)>>) do
    %RGB{
      red: hex_to_decimal(red),
      green: hex_to_decimal(green),
      blue: hex_to_decimal(blue)
    }
  end

  defp hex_to_rgb("#" <> base_color) do
    hex_to_rgb(base_color)
  end

  defp hex_to_decimal(hex) do
    {decimal, ""} = Integer.parse(hex, 16)

    decimal
  end

  def shades_to_css(name, base_color \\ nil, overrides \\ %{}) do
    get_shades(base_color, overrides)
    |> Map.to_list()
    |> Enum.reduce([], fn {key, shade}, list -> list ++ ["--color-#{name}-#{key}: #{shade};"] end)
    |> Enum.join("\n")
  end
end
