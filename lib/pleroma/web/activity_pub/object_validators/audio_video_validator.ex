# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.AudioVideoValidator do
  use Ecto.Schema

  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Ecto.Changeset

  @primary_key false
  @derive Jason.Encoder

  embedded_schema do
    quote do
      unquote do
        import Elixir.Pleroma.Web.ActivityPub.ObjectValidators.CommonFields
        message_fields()
        object_fields()
        status_object_fields()
      end
    end
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

  defp find_attachment(url) do
    mpeg_url =
      Enum.find(url, fn
        %{"mediaType" => mime_type, "tag" => tags} when is_list(tags) ->
          mime_type == "application/x-mpegURL"

        _ ->
          false
      end)

    url
    |> Enum.concat(mpeg_url["tag"] || [])
    |> Enum.find(fn
      %{"mediaType" => mime_type} -> String.starts_with?(mime_type, ["video/", "audio/"])
      %{"mimeType" => mime_type} -> String.starts_with?(mime_type, ["video/", "audio/"])
      _ -> false
    end)
  end

  defp fix_url(%{"url" => url} = data) when is_list(url) do
    attachment = find_attachment(url)

    link_element =
      Enum.find(url, fn
        %{"mediaType" => "text/html"} -> true
        %{"mimeType" => "text/html"} -> true
        _ -> false
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
      |> Pleroma.Formatter.markdown_to_html()
      |> Pleroma.HTML.filter_tags()

    Map.put(data, "content", content)
  end

  defp fix_content(data), do: data

  defp fix(data) do
    data
    |> CommonFixes.fix_actor()
    |> CommonFixes.fix_object_defaults()
    |> Transmogrifier.fix_emoji()
    |> fix_url()
    |> fix_content()
  end

  def changeset(struct, data) do
    data = fix(data)

    struct
    |> cast(data, __schema__(:fields) -- [:attachment, :tag])
    |> cast_embed(:attachment)
    |> cast_embed(:tag)
  end

  defp validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["Audio", "Video"])
    |> validate_required([:id, :actor, :attributedTo, :type, :context, :attachment])
    |> CommonValidations.validate_any_presence([:cc, :to])
    |> CommonValidations.validate_fields_match([:actor, :attributedTo])
    |> CommonValidations.validate_actor_presence()
    |> CommonValidations.validate_host_match()
  end
end
