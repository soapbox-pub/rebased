# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.NoPlaceholderTextPolicy do
  @moduledoc "Ensure no content placeholder is present (such as the dot from mastodon)"
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @impl true
  def history_awareness, do: :auto

  @impl true
  def filter(
        %{
          "type" => type,
          "object" => %{"content" => content, "attachment" => _} = _object
        } = activity
      )
      when type in ["Create", "Update"] and content in [".", "<p>.</p>"] do
    {:ok, put_in(activity, ["object", "content"], "")}
  end

  @impl true
  def filter(activity), do: {:ok, activity}

  @impl true
  def describe, do: {:ok, %{}}
end
