# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Tests.Helpers do
  @moduledoc """
  Helpers for use in tests.
  """

  defmacro __using__(_opts) do
    quote do
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
    end
  end
end
