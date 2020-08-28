# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.AttachmentValidator do
  use Ecto.Schema

  alias Pleroma.Web.ActivityPub.ObjectValidators.UrlObjectValidator

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string)
    field(:mediaType, :string, default: "application/octet-stream")
    field(:name, :string)

    embeds_many(:url, UrlObjectValidator)
  end

  def cast_and_validate(data) do
    data
    |> cast_data()
    |> validate_data()
  end

  def cast_data(data) do
    %__MODULE__{}
    |> changeset(data)
  end

  def changeset(struct, data) do
    data =
      data
      |> fix_media_type()
      |> fix_url()

    struct
    |> cast(data, [:type, :mediaType, :name])
    |> cast_embed(:url, required: true)
  end

  def fix_media_type(data) do
    data = Map.put_new(data, "mediaType", data["mimeType"])

    if MIME.valid?(data["mediaType"]) do
      data
    else
      Map.put(data, "mediaType", "application/octet-stream")
    end
  end

  defp handle_href(href, mediaType) do
    [
      %{
        "href" => href,
        "type" => "Link",
        "mediaType" => mediaType
      }
    ]
  end

  defp fix_url(data) do
    cond do
      is_binary(data["url"]) ->
        Map.put(data, "url", handle_href(data["url"], data["mediaType"]))

      is_binary(data["href"]) and data["url"] == nil ->
        Map.put(data, "url", handle_href(data["href"], data["mediaType"]))

      true ->
        data
    end
  end

  def validate_data(cng) do
    cng
    |> validate_required([:mediaType, :url, :type])
  end
end
