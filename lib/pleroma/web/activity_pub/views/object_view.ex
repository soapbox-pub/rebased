# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectView do
  use Pleroma.Web, :view
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Transmogrifier

  def render("object.json", %{object: %Object{} = object}) do
    base = Pleroma.Web.ActivityPub.Utils.make_json_ld_header()

    additional = Transmogrifier.prepare_object(object.data)
    Map.merge(base, additional)
  end

  def render("object.json", %{object: %Activity{data: %{"type" => "Create"}} = activity}) do
    base = Pleroma.Web.ActivityPub.Utils.make_json_ld_header()
    object = Object.normalize(activity)

    additional =
      Transmogrifier.prepare_object(activity.data)
      |> Map.put("object", Transmogrifier.prepare_object(object.data))

    Map.merge(base, additional)
  end

  def render("object.json", %{object: %Activity{} = activity}) do
    base = Pleroma.Web.ActivityPub.Utils.make_json_ld_header()
    object = Object.normalize(activity)

    additional =
      Transmogrifier.prepare_object(activity.data)
      |> Map.put("object", object.data["id"])

    Map.merge(base, additional)
  end

  def render("likes.json", ap_id, likes, page) do
    collection(likes, "#{ap_id}/likes", page)
    |> Map.merge(Pleroma.Web.ActivityPub.Utils.make_json_ld_header())
  end

  def render("likes.json", ap_id, likes) do
    %{
      "id" => "#{ap_id}/likes",
      "type" => "OrderedCollection",
      "totalItems" => length(likes),
      "first" => collection(likes, "#{ap_id}/likes", 1)
    }
    |> Map.merge(Pleroma.Web.ActivityPub.Utils.make_json_ld_header())
  end

  def collection(collection, iri, page) do
    offset = (page - 1) * 10
    items = Enum.slice(collection, offset, 10)
    items = Enum.map(items, fn object -> Transmogrifier.prepare_object(object.data) end)
    total = length(collection)

    map = %{
      "id" => "#{iri}?page=#{page}",
      "type" => "OrderedCollectionPage",
      "partOf" => iri,
      "totalItems" => total,
      "orderedItems" => items
    }

    if offset + length(items) < total do
      Map.put(map, "next", "#{iri}?page=#{page + 1}")
    else
      map
    end
  end
end
