# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Tests.Helpers do
  @moduledoc """
  Helpers for use in tests.
  """
  alias Pleroma.Config

  require Logger

  defmacro clear_config(config_path) do
    quote do
      clear_config(unquote(config_path)) do
      end
    end
  end

  defmacro clear_config(config_path, do: yield) do
    quote do
      initial_setting = Config.fetch(unquote(config_path))

      unquote(yield)

      on_exit(fn ->
        case initial_setting do
          :error ->
            Config.delete(unquote(config_path))

          {:ok, value} ->
            Config.put(unquote(config_path), value)
        end
      end)

      :ok
    end
  end

  defmacro clear_config(config_path, temp_setting) do
    # NOTE: `clear_config([section, key], value)` != `clear_config([section], key: value)` (!)
    # Displaying a warning to prevent unintentional clearing of all but one keys in section
    if Keyword.keyword?(temp_setting) and length(temp_setting) == 1 do
      Logger.warn(
        "Please change `clear_config([section], key: value)` to `clear_config([section, key], value)`"
      )
    end

    quote do
      clear_config(unquote(config_path)) do
        Config.put(unquote(config_path), unquote(temp_setting))
      end
    end
  end

  def require_migration(migration_name) do
    [{module, _}] = Code.require_file("#{migration_name}.exs", "priv/repo/migrations")
    {:ok, %{migration: module}}
  end

  defmacro __using__(_opts) do
    quote do
      import Pleroma.Tests.Helpers,
        only: [
          clear_config: 1,
          clear_config: 2
        ]

      def time_travel(entity, seconds) do
        new_time = NaiveDateTime.add(entity.inserted_at, seconds)

        entity
        |> Ecto.Changeset.change(%{inserted_at: new_time, updated_at: new_time})
        |> Pleroma.Repo.update()
      end

      def to_datetime(%NaiveDateTime{} = naive_datetime) do
        naive_datetime
        |> DateTime.from_naive!("Etc/UTC")
        |> DateTime.truncate(:second)
      end

      def to_datetime(datetime) when is_binary(datetime) do
        datetime
        |> NaiveDateTime.from_iso8601!()
        |> to_datetime()
      end

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
        |> Jason.encode!()
        |> Jason.decode!()
      end

      def stringify_keys(nil), do: nil

      def stringify_keys(key) when key in [true, false], do: key
      def stringify_keys(key) when is_atom(key), do: Atom.to_string(key)

      def stringify_keys(map) when is_map(map) do
        map
        |> Enum.map(fn {k, v} -> {stringify_keys(k), stringify_keys(v)} end)
        |> Enum.into(%{})
      end

      def stringify_keys([head | rest] = list) when is_list(list) do
        [stringify_keys(head) | stringify_keys(rest)]
      end

      def stringify_keys(key), do: key

      defmacro guards_config(config_path) do
        quote do
          initial_setting = Config.get(config_path)

          Config.put(config_path, true)
          on_exit(fn -> Config.put(config_path, initial_setting) end)
        end
      end
    end
  end
end
