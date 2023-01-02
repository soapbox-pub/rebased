# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Utils do
  @posix_error_codes ~w(
    eacces eagain ebadf ebadmsg ebusy edeadlk edeadlock edquot eexist efault
    efbig eftype eintr einval eio eisdir eloop emfile emlink emultihop
    enametoolong enfile enobufs enodev enolck enolink enoent enomem enospc
    enosr enostr enosys enotblk enotdir enotsup enxio eopnotsupp eoverflow
    eperm epipe erange erofs espipe esrch estale etxtbsy exdev
  )a

  @repo_timeout Pleroma.Config.get([Pleroma.Repo, :timeout], 15_000)

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
    case :os.find_executable(String.to_charlist(command)) do
      false -> false
      _ -> true
    end
  end

  @doc "creates the uniq temporary directory"
  @spec tmp_dir(String.t()) :: {:ok, String.t()} | {:error, :file.posix()}
  def tmp_dir(prefix \\ "") do
    sub_dir =
      [
        prefix,
        Timex.to_unix(Timex.now()),
        :os.getpid(),
        String.downcase(Integer.to_string(:rand.uniform(0x100000000), 36))
      ]
      |> Enum.join("-")

    tmp_dir = Path.join(System.tmp_dir!(), sub_dir)

    case File.mkdir(tmp_dir) do
      :ok -> {:ok, tmp_dir}
      error -> error
    end
  end

  @spec posix_error_message(atom()) :: binary()
  def posix_error_message(code) when code in @posix_error_codes do
    error_message = Gettext.dgettext(Pleroma.Web.Gettext, "posix_errors", "#{code}")
    "(POSIX error: #{error_message})"
  end

  def posix_error_message(_), do: ""

  @doc """
  Returns [timeout: integer] suitable for passing as an option to Repo functions.

  This function detects if the execution was triggered from IEx shell, Mix task, or
  ./bin/pleroma_ctl and sets the timeout to :infinity, else returns the default timeout value.
  """
  @spec query_timeout() :: [timeout: integer]
  def query_timeout do
    {parent, _, _, _} = Process.info(self(), :current_stacktrace) |> elem(1) |> Enum.fetch!(2)

    cond do
      parent |> to_string |> String.starts_with?("Elixir.Mix.Task") -> [timeout: :infinity]
      parent == :erl_eval -> [timeout: :infinity]
      true -> [timeout: @repo_timeout]
    end
  end
end
