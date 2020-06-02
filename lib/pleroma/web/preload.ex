# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Preload do
  alias Phoenix.HTML
  require Logger

  def build_tags(_conn, params) do
    preload_data =
      Enum.reduce(Pleroma.Config.get([__MODULE__, :providers], []), %{}, fn parser, acc ->
        Map.merge(acc, parser.generate_terms(params))
      end)

    rendered_html =
      preload_data
      |> Jason.encode!()
      |> build_script_tag()
      |> HTML.safe_to_string()

    rendered_html
  end

  def build_script_tag(content) do
    content = Base.encode64(content)

    HTML.Tag.content_tag(:script, HTML.raw(content),
      id: "initial-results",
      type: "application/json"
    )
  end
end
