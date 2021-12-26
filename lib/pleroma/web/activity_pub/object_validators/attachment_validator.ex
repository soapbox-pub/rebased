# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.AttachmentValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string)
    field(:mediaType, :string, default: "application/octet-stream")
    field(:name, :string)
    field(:blurhash, :string)

    embeds_many :url, UrlObjectValidator, primary_key: false do
      field(:type, :string)
      field(:href, ObjectValidators.Uri)
      field(:mediaType, :string, default: "application/octet-stream")
      field(:width, :integer)
      field(:height, :integer)
    end
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
    |> cast(data, [:type, :mediaType, :name, :blurhash])
    |> cast_embed(:url, with: &url_changeset/2)
    |> validate_inclusion(:type, ~w[Link Document Audio Image Video])
    |> validate_required([:type, :mediaType, :url])
  end

  def url_changeset(struct, data) do
    data = fix_media_type(data)

    struct
    |> cast(data, [:type, :href, :mediaType, :width, :height])
    |> validate_inclusion(:type, ["Link"])
    |> validate_required([:type, :href, :mediaType])
  end

  def fix_media_type(data) do
    data = Map.put_new(data, "mediaType", data["mimeType"])

    if is_bitstring(data["mediaType"]) && MIME.extensions(data["mediaType"]) != [] do
      data
    else
      Map.put(data, "mediaType", "application/octet-stream")
    end
  end

  defp handle_href(href, mediaType, data) do
    [
      %{
        "href" => href,
        "type" => "Link",
        "mediaType" => mediaType,
        "width" => data["width"],
        "height" => data["height"]
      }
    ]
  end

  defp fix_url(data) do
    cond do
      is_binary(data["url"]) ->
        Map.put(data, "url", handle_href(data["url"], data["mediaType"], data))

      is_binary(data["href"]) and data["url"] == nil ->
        Map.put(data, "url", handle_href(data["href"], data["mediaType"], data))

      true ->
        data
    end
  end

  defp validate_data(cng) do
    cng
    |> validate_inclusion(:type, ~w[Document Audio Image Video])
    |> validate_required([:mediaType, :url, :type])
  end
end
