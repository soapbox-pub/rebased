# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.AudioVideoValidator do
  use Ecto.Schema

  alias Pleroma.EarmarkRenderer
  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Web.ActivityPub.ObjectValidators.AttachmentValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Ecto.Changeset

  @primary_key false
  @derive Jason.Encoder

  embedded_schema do
    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:to, ObjectValidators.Recipients, default: [])
    field(:cc, ObjectValidators.Recipients, default: [])
    field(:bto, ObjectValidators.Recipients, default: [])
    field(:bcc, ObjectValidators.Recipients, default: [])
    # TODO: Write type
    field(:tag, {:array, :map}, default: [])
    field(:type, :string)

    field(:name, :string)
    field(:summary, :string)
    field(:content, :string)

    field(:context, :string)
    # short identifier for PleromaFE to group statuses by context
    field(:context_id, :integer)

    # TODO: Remove actor on objects
    field(:actor, ObjectValidators.ObjectID)

    field(:attributedTo, ObjectValidators.ObjectID)
    field(:published, ObjectValidators.DateTime)
    field(:emoji, ObjectValidators.Emoji, default: %{})
    field(:sensitive, :boolean, default: false)
    embeds_many(:attachment, AttachmentValidator)
    field(:replies_count, :integer, default: 0)
    field(:like_count, :integer, default: 0)
    field(:announcement_count, :integer, default: 0)
    field(:inReplyTo, ObjectValidators.ObjectID)
    field(:url, ObjectValidators.Uri)

    field(:likes, {:array, ObjectValidators.ObjectID}, default: [])
    field(:announcements, {:array, ObjectValidators.ObjectID}, default: [])
  end

  def cast_and_apply(data) do
    data
    |> cast_data
    |> apply_action(:insert)
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

  defp fix_url(%{"url" => url} = data) when is_list(url) do
    attachment =
      Enum.find(url, fn x ->
        mime_type = x["mimeType"] || x["mediaType"] || ""

        is_map(x) and String.starts_with?(mime_type, ["video/", "audio/"])
      end)

    link_element =
      Enum.find(url, fn x ->
        mime_type = x["mimeType"] || x["mediaType"] || ""

        is_map(x) and mime_type == "text/html"
      end)

    data
    |> Map.put("attachment", [attachment])
    |> Map.put("url", link_element["href"])
  end

  defp fix_url(data), do: data

  defp fix_content(%{"mediaType" => "text/markdown", "content" => content} = data)
       when is_binary(content) do
    content =
      content
      |> Earmark.as_html!(%Earmark.Options{renderer: EarmarkRenderer})
      |> Pleroma.HTML.filter_tags()

    Map.put(data, "content", content)
  end

  defp fix_content(data), do: data

  defp fix(data) do
    data
    |> CommonFixes.fix_defaults()
    |> CommonFixes.fix_attribution()
    |> CommonFixes.fix_actor()
    |> Transmogrifier.fix_emoji()
    |> fix_url()
    |> fix_content()
  end

  def changeset(struct, data) do
    data = fix(data)

    struct
    |> cast(data, __schema__(:fields) -- [:attachment])
    |> cast_embed(:attachment)
  end

  def validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["Audio", "Video"])
    |> validate_required([:id, :actor, :attributedTo, :type, :context, :attachment])
    |> CommonValidations.validate_any_presence([:cc, :to])
    |> CommonValidations.validate_fields_match([:actor, :attributedTo])
    |> CommonValidations.validate_actor_presence()
    |> CommonValidations.validate_host_match()
  end
end
