# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Helpers.QtFastStart do
  @moduledoc """
  (WIP) Converts a "slow start" (data before metadatas) mov/mp4 file to a "fast start" one (metadatas before data).
  """

  # TODO: Cleanup and optimizations
  # Inspirations: https://www.ffmpeg.org/doxygen/3.4/qt-faststart_8c_source.html
  #               https://github.com/danielgtaylor/qtfaststart/blob/master/qtfaststart/processor.py
  #               ISO/IEC 14496-12:2015, ISO/IEC 15444-12:2015
  #               Paracetamol

  def fix(binary = <<0x00, 0x00, 0x00, _, 0x66, 0x74, 0x79, 0x70, _::binary>>) do
    index = fix(binary, binary, 0, [])

    case index do
      [{"ftyp", _, _, _, _}, {"mdat", _, _, _, _} | _] -> faststart(index)
      [{"ftyp", _, _, _, _}, {"free", _, _, _, _}, {"mdat", _, _, _, _} | _] -> faststart(index)
      _ -> binary
    end
  end

  def fix(binary) do
    binary
  end

  defp fix(<<>>, _bin, _pos, acc) do
    :lists.reverse(acc)
  end

  defp fix(
         <<size::integer-big-size(4)-unit(8), fourcc::binary-size(4), rest::binary>>,
         bin,
         pos,
         acc
       ) do
    if fourcc == "mdat" && size == 0 do
      # mdat with 0 size means "seek to the end" -- also, in that case the file is probably OK.
      acc = [
        {fourcc, pos, byte_size(bin) - pos, byte_size(bin) - pos,
         <<size::integer-big-size(4)-unit(8), fourcc::binary-size(4), rest::binary>>}
        | acc
      ]

      fix(<<>>, bin, byte_size(bin), acc)
    else
      full_size = size - 8
      <<data::binary-size(full_size), rest::binary>> = rest

      acc = [
        {fourcc, pos, pos + size, size,
         <<size::integer-big-size(4)-unit(8), fourcc::binary-size(4), data::binary>>}
        | acc
      ]

      fix(rest, bin, pos + size, acc)
    end
  end

  defp faststart(index) do
    {{_ftyp, _, _, _, ftyp}, index} = List.keytake(index, "ftyp", 0)

    # Skip re-writing the free fourcc as it's kind of useless. Why stream useless bytes when you can do without?
    {free_size, index} =
      case List.keytake(index, "free", 0) do
        {{_, _, _, size, _}, index} -> {size, index}
        _ -> {0, index}
      end

    {{_moov, _, _, moov_size, moov}, index} = List.keytake(index, "moov", 0)
    offset = -free_size + moov_size
    rest = for {_, _, _, _, data} <- index, do: data, into: <<>>
    <<moov_head::binary-size(8), moov_data::binary>> = moov
    new_moov = fix_moov(moov_data, offset)
    <<ftyp::binary, moov_head::binary, new_moov::binary, rest::binary>>
  end

  defp fix_moov(moov, offset) do
    fix_moov(moov, offset, <<>>)
  end

  defp fix_moov(<<>>, _, acc), do: acc

  defp fix_moov(
         <<size::integer-big-size(4)-unit(8), fourcc::binary-size(4), rest::binary>>,
         offset,
         acc
       ) do
    full_size = size - 8
    <<data::binary-size(full_size), rest::binary>> = rest

    data =
      cond do
        fourcc in ["trak", "mdia", "minf", "stbl"] ->
          # Theses contains sto or co64 part
          <<size::integer-big-size(4)-unit(8), fourcc::binary-size(4),
            fix_moov(data, offset, <<>>)::binary>>

        fourcc in ["stco", "co64"] ->
          # fix the damn thing
          <<version::integer-big-size(4)-unit(8), count::integer-big-size(4)-unit(8),
            rest::binary>> = data

          entry_size =
            case fourcc do
              "stco" -> 4
              "co64" -> 8
            end

          {_, result} =
            Enum.reduce(1..count, {rest, <<>>}, fn _,
                                                   {<<pos::integer-big-size(entry_size)-unit(8),
                                                      rest::binary>>, acc} ->
              {rest, <<acc::binary, pos + offset::integer-big-size(entry_size)-unit(8)>>}
            end)

          <<size::integer-big-size(4)-unit(8), fourcc::binary-size(4),
            version::integer-big-size(4)-unit(8), count::integer-big-size(4)-unit(8),
            result::binary>>

        true ->
          <<size::integer-big-size(4)-unit(8), fourcc::binary-size(4), data::binary>>
      end

    acc = <<acc::binary, data::binary>>
    fix_moov(rest, offset, acc)
  end
end
