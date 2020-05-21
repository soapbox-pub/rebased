# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Helpers.MediaHelper do
  @moduledoc """
  Handles common media-related operations.
  """

  @ffmpeg_opts [{:sync, true}, {:stdout, true}]

  def ffmpeg_resize_remote(uri, %{max_width: max_width, max_height: max_height}) do
    cmd = ~s"""
    curl -L "#{uri}" |
    ffmpeg -i pipe:0 -f lavfi -i color=c=white \
      -filter_complex "[0:v] scale='min(#{max_width},iw)':'min(#{max_height},ih)': \
        force_original_aspect_ratio=decrease [scaled]; \
        [1][scaled] scale2ref [bg][img]; [bg] setsar=1 [bg]; [bg][img] overlay=shortest=1" \
      -f image2 -vcodec mjpeg -frames:v 1 pipe:1 | \
    cat
    """

    with {:ok, [stdout: stdout_list]} <- Exexec.run(cmd, @ffmpeg_opts) do
      {:ok, Enum.join(stdout_list)}
    end
  end
end
