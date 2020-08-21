# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Helpers.MediaHelper do
  @moduledoc """
  Handles common media-related operations.
  """

  def ffmpeg_resize(uri_or_path, %{max_width: max_width, max_height: max_height} = options) do
    quality = options[:quality] || 1

    cmd = ~s"""
    ffmpeg -i #{uri_or_path} -f lavfi -i color=c=white \
      -filter_complex "[0:v] scale='min(#{max_width},iw)':'min(#{max_height},ih)': \
        force_original_aspect_ratio=decrease [scaled]; \
        [1][scaled] scale2ref [bg][img]; [bg] setsar=1 [bg]; [bg][img] overlay=shortest=1" \
      -loglevel quiet -f image2 -vcodec mjpeg -frames:v 1 -q:v #{quality} pipe:1
    """

    pid = Port.open({:spawn, cmd}, [:use_stdio, :in, :stream, :exit_status, :binary])
    loop_recv(pid)
  end

  defp loop_recv(pid) do
    loop_recv(pid, <<>>)
  end

  defp loop_recv(pid, acc) do
    receive do
      {^pid, {:data, data}} ->
        loop_recv(pid, acc <> data)

      {^pid, {:exit_status, 0}} ->
        {:ok, acc}

      {^pid, {:exit_status, status}} ->
        {:error, status}
    end
  end

end
