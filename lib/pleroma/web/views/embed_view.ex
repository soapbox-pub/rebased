# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.EmbedView do
  use Pleroma.Web, :view

  alias Calendar.Strftime
  alias Pleroma.Activity
  alias Pleroma.Emoji.Formatter
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.Gettext
  alias Pleroma.Web.MediaProxy
  alias Pleroma.Web.Metadata.Utils
  alias Pleroma.Web.Router.Helpers

  use Phoenix.HTML

  defdelegate full_nickname(user), to: User

  @media_types ["image", "audio", "video"]

  defp fetch_media_type(%{"mediaType" => mediaType}) do
    Utils.fetch_media_type(@media_types, mediaType)
  end

  defp open_content? do
    Pleroma.Config.get(
      [:frontend_configurations, :collapse_message_with_subjects],
      true
    )
  end

  defp status_title(%Activity{object: %Object{data: %{"name" => name}}}) when is_binary(name),
    do: name

  defp status_title(%Activity{object: %Object{data: %{"summary" => summary}}})
       when is_binary(summary),
       do: summary

  defp status_title(_), do: nil

  defp activity_content(%Activity{object: %Object{data: %{"content" => content}}}) do
    content |> Pleroma.HTML.filter_tags() |> raw()
  end

  defp activity_content(_), do: nil

  defp activity_url(%User{local: true}, activity) do
    Helpers.o_status_url(Pleroma.Web.Endpoint, :notice, activity)
  end

  defp activity_url(%User{local: false}, %Activity{object: %Object{data: data}}) do
    data["url"] || data["external_url"] || data["id"]
  end

  defp attachments(%Activity{object: %Object{data: %{"attachment" => attachments}}}) do
    attachments
  end

  defp sensitive?(%Activity{object: %Object{data: %{"sensitive" => sensitive}}}) do
    sensitive
  end

  defp published(%Activity{object: %Object{data: %{"published" => published}}}) do
    published
    |> NaiveDateTime.from_iso8601!()
    |> Strftime.strftime!("%B %d, %Y, %l:%M %p")
  end
end
