# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.Mogrifun do
  @behaviour Pleroma.Upload.Filter
  alias Pleroma.Upload.Filter

  @filters [
    {"implode", "1"},
    {"-raise", "20"},
    {"+raise", "20"},
    [{"-interpolate", "nearest"}, {"-virtual-pixel", "mirror"}, {"-spread", "5"}],
    "+polaroid",
    {"-statistic", "Mode 10"},
    {"-emboss", "0x1.1"},
    {"-emboss", "0x2"},
    {"-colorspace", "Gray"},
    "-negate",
    [{"-channel", "green"}, "-negate"],
    [{"-channel", "red"}, "-negate"],
    [{"-channel", "blue"}, "-negate"],
    {"+level-colors", "green,gold"},
    {"+level-colors", ",DodgerBlue"},
    {"+level-colors", ",Gold"},
    {"+level-colors", ",Lime"},
    {"+level-colors", ",Red"},
    {"+level-colors", ",DarkGreen"},
    {"+level-colors", "firebrick,yellow"},
    {"+level-colors", "'rgb(102,75,25)',lemonchiffon"},
    [{"fill", "red"}, {"tint", "40"}],
    [{"fill", "green"}, {"tint", "40"}],
    [{"fill", "blue"}, {"tint", "40"}],
    [{"fill", "yellow"}, {"tint", "40"}]
  ]

  def filter(%Pleroma.Upload{tempfile: file, content_type: "image" <> _}) do
    Filter.Mogrify.do_filter(file, [Enum.random(@filters)])

    :ok
  end

  def filter(_), do: :ok
end
