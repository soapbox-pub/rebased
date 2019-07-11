# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ReleaseTasks do
  @repo Pleroma.Repo

  def run(args) do
    [task | args] = String.split(args)

    case task do
      "migrate" -> migrate(args)
      "create" -> create()
      "rollback" -> rollback(args)
      task -> mix_task(task, args)
    end
  end

  defp mix_task(task, args) do
    Application.load(:pleroma)
    {:ok, modules} = :application.get_key(:pleroma, :modules)

    module =
      Enum.find(modules, fn module ->
        module = Module.split(module)

        match?(["Mix", "Tasks", "Pleroma" | _], module) and
          String.downcase(List.last(module)) == task
      end)

    if module do
      module.run(args)
    else
      IO.puts("The task #{task} does not exist")
    end
  end

  def migrate(args) do
    Mix.Tasks.Pleroma.Ecto.Migrate.run(args)
  end

  def rollback(args) do
    Mix.Tasks.Pleroma.Ecto.Rollback.run(args)
  end

  def create do
    Application.load(:pleroma)

    case @repo.__adapter__.storage_up(@repo.config) do
      :ok ->
        IO.puts("The database for #{inspect(@repo)} has been created")

      {:error, :already_up} ->
        IO.puts("The database for #{inspect(@repo)} has already been created")

      {:error, term} when is_binary(term) ->
        IO.puts(:stderr, "The database for #{inspect(@repo)} couldn't be created: #{term}")

      {:error, term} ->
        IO.puts(
          :stderr,
          "The database for #{inspect(@repo)} couldn't be created: #{inspect(term)}"
        )
    end
  end
end
