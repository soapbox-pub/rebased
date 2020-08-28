# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Utils do
  def compile_dir(dir) when is_binary(dir) do
    dir
    |> File.ls!()
    |> Enum.map(&Path.join(dir, &1))
    |> Kernel.ParallelCompiler.compile()
  end

  @doc """
  POSIX-compliant check if command is available in the system

  ## Examples
      iex> command_available?("git")
      true
      iex> command_available?("wrongcmd")
      false

  """
  @spec command_available?(String.t()) :: boolean()
  def command_available?(command) do
    match?({_output, 0}, System.cmd("sh", ["-c", "command -v #{command}"]))
  end
end
