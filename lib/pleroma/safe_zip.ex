# Akkoma: Magically expressive social media
# Copyright © 2024 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.SafeZip do
  @moduledoc """
  Wraps the subset of Erlang's zip module we’d like to use
  but enforces path-traversal safety everywhere and other checks.

  For convenience almost all functions accept both elixir strings and charlists,
  but output elixir strings themselves. However, this means the input parameter type
  can no longer be used to distinguish archive file paths from archive binary data in memory,
  thus where needed both a _data and _file variant are provided.
  """

  @type text() :: String.t() | [char()]

  defp safe_path?(path) do
    # Path accepts elixir’s chardata()
    case Path.safe_relative(path) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp safe_type?(file_type) do
    if file_type in [:regular, :directory] do
      true
    else
      false
    end
  end

  defp maybe_add_file(_type, _path_charlist, nil), do: nil

  defp maybe_add_file(:regular, path_charlist, file_list),
    do: [to_string(path_charlist) | file_list]

  defp maybe_add_file(_type, _path_charlist, file_list), do: file_list

  @spec check_safe_archive_and_maybe_list_files(binary() | [char()], [term()], boolean()) ::
          {:ok, [String.t()]} | {:error, reason :: term()}
  defp check_safe_archive_and_maybe_list_files(archive, opts, list) do
    acc = if list, do: [], else: nil

    with {:ok, table} <- :zip.table(archive, opts) do
      Enum.reduce_while(table, {:ok, acc}, fn
        # ZIP comment
        {:zip_comment, _}, acc ->
          {:cont, acc}

        # File entry
        {:zip_file, path, info, _comment, _offset, _comp_size}, {:ok, fl} ->
          with {_, type} <- {:get_type, elem(info, 2)},
               {_, true} <- {:type, safe_type?(type)},
               {_, true} <- {:safe_path, safe_path?(path)} do
            {:cont, {:ok, maybe_add_file(type, path, fl)}}
          else
            {:get_type, e} ->
              {:halt,
               {:error, "Couldn't determine file type of ZIP entry at #{path} (#{inspect(e)})"}}

            {:type, _} ->
              {:halt, {:error, "Potentially unsafe file type in ZIP at: #{path}"}}

            {:safe_path, _} ->
              {:halt, {:error, "Unsafe path in ZIP: #{path}"}}
          end

        # new OTP version?
        _, _acc ->
          {:halt, {:error, "Unknown ZIP record type"}}
      end)
    end
  end

  @spec check_safe_archive_and_list_files(binary() | [char()], [term()]) ::
          {:ok, [String.t()]} | {:error, reason :: term()}
  defp check_safe_archive_and_list_files(archive, opts \\ []) do
    check_safe_archive_and_maybe_list_files(archive, opts, true)
  end

  @spec check_safe_archive(binary() | [char()], [term()]) :: :ok | {:error, reason :: term()}
  defp check_safe_archive(archive, opts \\ []) do
    case check_safe_archive_and_maybe_list_files(archive, opts, false) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @spec check_safe_file_list([text()], text()) :: :ok | {:error, term()}
  defp check_safe_file_list([], _), do: :ok

  defp check_safe_file_list([path | tail], cwd) do
    with {_, true} <- {:path, safe_path?(path)},
         {_, {:ok, fstat}} <- {:stat, File.stat(Path.expand(path, cwd))},
         {_, true} <- {:type, safe_type?(fstat.type)} do
      check_safe_file_list(tail, cwd)
    else
      {:path, _} ->
        {:error, "Unsafe path escaping cwd: #{path}"}

      {:stat, e} ->
        {:error, "Unable to check file type of #{path}: #{inspect(e)}"}

      {:type, _} ->
        {:error, "Unsafe type at #{path}"}
    end
  end

  defp check_safe_file_list(_, _), do: {:error, "Malformed file_list"}

  @doc """
  Checks whether the archive data contais file entries for all paths from fset

  Note this really only accepts entries corresponding to regular _files_,
  if a path is contained as for example an directory, this does not count as a match.
  """
  @spec contains_all_data?(binary(), MapSet.t()) :: true | false
  def contains_all_data?(archive_data, fset) do
    with {:ok, table} <- :zip.table(archive_data) do
      remaining =
        Enum.reduce(table, fset, fn
          {:zip_file, path, info, _comment, _offset, _comp_size}, fset ->
            if elem(info, 2) == :regular do
              MapSet.delete(fset, path)
            else
              fset
            end

          _, _ ->
            fset
        end)
        |> MapSet.size()

      if remaining == 0, do: true, else: false
    else
      _ -> false
    end
  end

  @doc """
  List all file entries in ZIP, or error if invalid or unsafe.

  Note this really only lists regular files, no directories, ZIP comments or other types!
  """
  @spec list_dir_file(text()) :: {:ok, [String.t()]} | {:error, reason :: term()}
  def list_dir_file(archive) do
    path = to_charlist(archive)
    check_safe_archive_and_list_files(path)
  end

  defp stringify_zip({:ok, {fname, data}}), do: {:ok, {to_string(fname), data}}
  defp stringify_zip({:ok, fname}), do: {:ok, to_string(fname)}
  defp stringify_zip(ret), do: ret

  @spec zip(text(), text(), [text()], boolean()) ::
          {:ok, file_name :: String.t()}
          | {:ok, {file_name :: String.t(), file_data :: binary()}}
          | {:error, reason :: term()}
  def zip(name, file_list, cwd, memory \\ false) do
    opts = [{:cwd, to_charlist(cwd)}]
    opts = if memory, do: [:memory | opts], else: opts

    with :ok <- check_safe_file_list(file_list, cwd) do
      file_list = for f <- file_list, do: to_charlist(f)
      name = to_charlist(name)
      stringify_zip(:zip.zip(name, file_list, opts))
    end
  end

  @spec unzip_file(text(), text(), [text()] | nil) ::
          {:ok, [String.t()]}
          | {:error, reason :: term()}
          | {:error, {name :: text(), reason :: term()}}
  def unzip_file(archive, target_dir, file_list \\ nil) do
    do_unzip(to_charlist(archive), to_charlist(target_dir), file_list)
  end

  @spec unzip_data(binary(), text(), [text()] | nil) ::
          {:ok, [String.t()]}
          | {:error, reason :: term()}
          | {:error, {name :: text(), reason :: term()}}
  def unzip_data(archive, target_dir, file_list \\ nil) do
    do_unzip(archive, to_charlist(target_dir), file_list)
  end

  defp stringify_unzip({:ok, [{_fname, _data} | _] = filebinlist}),
    do: {:ok, Enum.map(filebinlist, fn {fname, data} -> {to_string(fname), data} end)}

  defp stringify_unzip({:ok, [_fname | _] = filelist}),
    do: {:ok, Enum.map(filelist, fn fname -> to_string(fname) end)}

  defp stringify_unzip({:error, {fname, term}}), do: {:error, {to_string(fname), term}}
  defp stringify_unzip(ret), do: ret

  @spec do_unzip(binary() | [char()], text(), [text()] | nil) ::
          {:ok, [String.t()]}
          | {:error, reason :: term()}
          | {:error, {name :: text(), reason :: term()}}
  defp do_unzip(archive, target_dir, file_list) do
    opts =
      if file_list != nil do
        [
          file_list: for(f <- file_list, do: to_charlist(f)),
          cwd: target_dir
        ]
      else
        [cwd: target_dir]
      end

    with :ok <- check_safe_archive(archive) do
      stringify_unzip(:zip.unzip(archive, opts))
    end
  end
end
