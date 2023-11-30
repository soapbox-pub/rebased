# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Helpers.MediaHelper do
  @moduledoc """
  Handles common media-related operations.
  """

  alias Pleroma.HTTP
  alias Vix.Vips.Operation

  require Logger

  def missing_dependencies do
    Enum.reduce([ffmpeg: "ffmpeg"], [], fn {sym, executable}, acc ->
      if Pleroma.Utils.command_available?(executable) do
        acc
      else
        [sym | acc]
      end
    end)
  end

  def image_resize(url, options) do
    with {:ok, env} <- HTTP.get(url, [], pool: :media),
         {:ok, resized} <-
           Operation.thumbnail_buffer(env.body, options.max_width,
             height: options.max_height,
             size: :VIPS_SIZE_DOWN
           ) do
      if options[:format] == "png" do
        Operation.pngsave_buffer(resized, Q: options[:quality])
      else
        Operation.jpegsave_buffer(resized, Q: options[:quality], interlace: true)
      end
    else
      {:error, _} = error -> error
    end
  end

  # Note: video thumbnail is intentionally not resized (always has original dimensions)
  def video_framegrab(url) do
    with executable when is_binary(executable) <- System.find_executable("ffmpeg"),
         {:ok, env} <- HTTP.get(url, [], pool: :media),
         {:ok, fifo_path} <- mkfifo(),
         args = [
           "-y",
           "-i",
           fifo_path,
           "-vframes",
           "1",
           "-f",
           "mjpeg",
           "-loglevel",
           "error",
           "-"
         ] do
      run_fifo(fifo_path, env, executable, args)
    else
      nil -> {:error, {:ffmpeg, :command_not_found}}
      {:error, _} = error -> error
    end
  end

  defp run_fifo(fifo_path, env, executable, args) do
    pid =
      Port.open({:spawn_executable, executable}, [
        :use_stdio,
        :stream,
        :exit_status,
        :binary,
        args: args
      ])

    fifo = Port.open(to_charlist(fifo_path), [:eof, :binary, :stream, :out])
    fix = Pleroma.Helpers.QtFastStart.fix(env.body)
    true = Port.command(fifo, fix)
    :erlang.port_close(fifo)
    loop_recv(pid)
  after
    File.rm(fifo_path)
  end

  defp mkfifo do
    path = Path.join(System.tmp_dir!(), "pleroma-media-preview-pipe-#{Ecto.UUID.generate()}")

    case System.cmd("mkfifo", [path]) do
      {_, 0} ->
        spawn(fifo_guard(path))
        {:ok, path}

      {_, err} ->
        {:error, {:fifo_failed, err}}
    end
  end

  defp fifo_guard(path) do
    pid = self()

    fn ->
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _} ->
          File.rm(path)
      end
    end
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
    after
      5000 ->
        :erlang.port_close(pid)
        {:error, :timeout}
    end
  end
end
