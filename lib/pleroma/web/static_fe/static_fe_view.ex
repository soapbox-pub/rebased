# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StaticFE.StaticFEView do
  use Pleroma.Web, :view

  alias Calendar.Strftime
  alias Pleroma.Emoji.Formatter
  alias Pleroma.User
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Gettext
  alias Pleroma.Web.MediaProxy
  alias Pleroma.Web.Metadata.Utils
  alias Pleroma.Web.Router.Helpers

  use Phoenix.HTML

  @media_types ["image", "audio", "video"]

  def fetch_media_type(%{"mediaType" => mediaType}) do
    Utils.fetch_media_type(@media_types, mediaType)
  end

  def format_date(date) do
    {:ok, date, _} = DateTime.from_iso8601(date)
    Strftime.strftime!(date, "%Y/%m/%d %l:%M:%S %p UTC")
  end

  def instance_name, do: Pleroma.Config.get([:instance, :name], "Pleroma")

  def open_content? do
    Pleroma.Config.get(
      [:frontend_configurations, :collapse_message_with_subjects],
      true
    )
  end
end
