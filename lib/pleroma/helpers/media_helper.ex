# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Helpers.MediaHelper do
  @moduledoc """
  Handles common media-related operations.
  """

  @ffmpeg_opts [{:sync, true}, {:stdout, true}]

  def ffmpeg_resize_remote(uri, max_width, max_height) do
    cmd = ~s"""
    curl -L "#{uri}" |
    ffmpeg -i pipe:0 -vf \
      "scale='min(#{max_width},iw)':min'(#{max_height},ih)':force_original_aspect_ratio=decrease" \
      -f image2 pipe:1 | \
    cat
    """

    with {:ok, [stdout: stdout_list]} <- Exexec.run(cmd, @ffmpeg_opts) do
      {:ok, Enum.join(stdout_list)}
    end
  end

  @doc "Returns a temporary path for an URI"
  def temporary_path_for(uri) do
    name = Path.basename(uri)
    random = rand_uniform(999_999)
    Path.join(System.tmp_dir(), "#{random}-#{name}")
  end

  @doc "Stores binary content fetched from specified URL as a temporary file."
  @spec store_as_temporary_file(String.t(), binary()) :: {:ok, String.t()} | {:error, atom()}
  def store_as_temporary_file(url, body) do
    path = temporary_path_for(url)
    with :ok <- File.write(path, body), do: {:ok, path}
  end

  @doc "Modifies image file at specified path by resizing to specified limit dimensions."
  @spec mogrify_resize_to_limit(String.t(), String.t()) :: :ok | any()
  def mogrify_resize_to_limit(path, resize_dimensions) do
    with %Mogrify.Image{} <-
           path
           |> Mogrify.open()
           |> Mogrify.resize_to_limit(resize_dimensions)
           |> Mogrify.save(in_place: true) do
      :ok
    end
  end

  defp rand_uniform(high) do
    Code.ensure_loaded(:rand)

    if function_exported?(:rand, :uniform, 1) do
      :rand.uniform(high)
    else
      # Erlang/OTP < 19
      apply(:crypto, :rand_uniform, [1, high])
    end
  end
end
