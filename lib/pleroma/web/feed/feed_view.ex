# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Feed.FeedView do
  use Phoenix.HTML
  use Pleroma.Web, :view

  alias Pleroma.Formatter
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.MediaProxy

  require Pleroma.Constants

  def prepare_activity(activity) do
    object = activity_object(activity)

    %{
      activity: activity,
      data: Map.get(object, :data),
      object: object
    }
  end

  def most_recent_update(activities, user) do
    (List.first(activities) || user).updated_at
    |> NaiveDateTime.to_iso8601()
  end

  def logo(user) do
    user
    |> User.avatar_url()
    |> MediaProxy.url()
  end

  def last_activity(activities), do: List.last(activities)

  def activity_object(activity), do: Object.normalize(activity)

  def activity_title(%{data: %{"content" => content}}, opts \\ %{}) do
    content
    |> Formatter.truncate(opts[:max_length], opts[:omission])
    |> escape()
  end

  def activity_content(%{data: %{"content" => content}}) do
    content
    |> String.replace(~r/[\n\r]/, "")
    |> escape()
  end

  def activity_context(activity), do: activity.data["context"]

  def attachment_href(attachment) do
    attachment["url"]
    |> hd()
    |> Map.get("href")
  end

  def attachment_type(attachment) do
    attachment["url"]
    |> hd()
    |> Map.get("mediaType")
  end

  def get_href(id) do
    with %Object{data: %{"external_url" => external_url}} <- Object.get_cached_by_ap_id(id) do
      external_url
    else
      _e -> id
    end
  end

  def escape(html) do
    html
    |> html_escape()
    |> safe_to_string()
  end
end
