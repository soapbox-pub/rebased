# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ReleaseTasks do
  def run(args) do
    [task | args] = String.split(args)

    case task do
      "migrate" -> migrate(args)
      task -> mix_task(task, args)
    end
  end

  defp mix_task(task, args) do
    # Modules are not loaded before application starts
    Mix.Tasks.Pleroma.Common.start_pleroma()
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

  defp migrate(_args) do
    :noop
  end
end
