# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Tests.Helpers do
  @moduledoc """
  Helpers for use in tests.
  """

  defmacro clear_config(config_path) do
    quote do
      clear_config(unquote(config_path)) do
      end
    end
  end

  defmacro clear_config(config_path, do: yield) do
    quote do
      setup do
        initial_setting = Pleroma.Config.get(unquote(config_path))
        unquote(yield)
        on_exit(fn -> Pleroma.Config.put(unquote(config_path), initial_setting) end)
        :ok
      end
    end
  end

  defmacro clear_config_all(config_path) do
    quote do
      clear_config_all(unquote(config_path)) do
      end
    end
  end

  defmacro clear_config_all(config_path, do: yield) do
    quote do
      setup_all do
        initial_setting = Pleroma.Config.get(unquote(config_path))
        unquote(yield)
        on_exit(fn -> Pleroma.Config.put(unquote(config_path), initial_setting) end)
        :ok
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      import Pleroma.Tests.Helpers,
        only: [
          clear_config: 1,
          clear_config: 2,
          clear_config_all: 1,
          clear_config_all: 2
        ]

      def collect_ids(collection) do
        collection
        |> Enum.map(& &1.id)
        |> Enum.sort()
      end

      def refresh_record(%{id: id, __struct__: model} = _),
        do: refresh_record(model, %{id: id})

      def refresh_record(model, %{id: id} = _) do
        Pleroma.Repo.get_by(model, id: id)
      end

      # Used for comparing json rendering during tests.
      def render_json(view, template, assigns) do
        assigns = Map.new(assigns)

        view.render(template, assigns)
        |> Poison.encode!()
        |> Poison.decode!()
      end

      defmacro guards_config(config_path) do
        quote do
          initial_setting = Pleroma.Config.get(config_path)

          Pleroma.Config.put(config_path, true)
          on_exit(fn -> Pleroma.Config.put(config_path, initial_setting) end)
        end
      end
    end
  end
end
