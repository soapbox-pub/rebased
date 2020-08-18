# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Helpers.MediaHelper do
  @moduledoc """
  Handles common media-related operations.
  """

  def ffmpeg_resize(uri_or_path, %{max_width: max_width, max_height: max_height}) do
    cmd = ~s"""
    ffmpeg -i #{uri_or_path} -f lavfi -i color=c=white \
      -filter_complex "[0:v] scale='min(#{max_width},iw)':'min(#{max_height},ih)': \
        force_original_aspect_ratio=decrease [scaled]; \
        [1][scaled] scale2ref [bg][img]; [bg] setsar=1 [bg]; [bg][img] overlay=shortest=1" \
      -loglevel quiet -f image2 -vcodec mjpeg -frames:v 1 pipe:1
    """

    pid = Port.open({:spawn, cmd}, [:use_stdio, :in, :stream, :exit_status, :binary])

    receive do
      {^pid, {:data, data}} ->
        send(pid, {self(), :close})
        {:ok, data}

      {^pid, {:exit_status, status}} when status > 0 ->
        {:error, status}
    end
  end
end
