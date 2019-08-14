# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.NoPlaceholderTextPolicy do
  @moduledoc "Ensure no content placeholder is present (such as the dot from mastodon)"
  @behaviour Pleroma.Web.ActivityPub.MRF

  @impl true
  def filter(
        %{
          "type" => "Create",
          "object" => %{"content" => content, "attachment" => _} = _child_object
        } = object
      )
      when content in [".", "<p>.</p>"] do
    {:ok, put_in(object, ["object", "content"], "")}
  end

  @impl true
  def filter(object), do: {:ok, object}

  @impl true
  def describe, do: {:ok, %{}}
end
