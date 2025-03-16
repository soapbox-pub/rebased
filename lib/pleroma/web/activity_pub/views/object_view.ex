# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectView do
  use Pleroma.Web, :view
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Transmogrifier

  def render("object.json", %{object: %Object{} = object} = opts) do
    base = Pleroma.Web.ActivityPub.Utils.make_json_ld_header(object.data)

    additional = Transmogrifier.prepare_object(object.data, Map.get(opts, :host))
    Map.merge(base, additional)
  end

  def render(
        "object.json",
        %{object: %Activity{data: %{"type" => activity_type}} = activity} = opts
      )
      when activity_type in ["Create", "Listen"] do
    base = Pleroma.Web.ActivityPub.Utils.make_json_ld_header(activity.data)
    object = Object.normalize(activity, fetch: false)

    additional =
      Transmogrifier.prepare_object(activity.data)
      |> Map.put("object", Transmogrifier.prepare_object(object.data, Map.get(opts, :host)))

    Map.merge(base, additional)
  end

  def render("object.json", %{object: %Activity{} = activity} = opts) do
    base = Pleroma.Web.ActivityPub.Utils.make_json_ld_header(activity.data)
    object_id = Object.normalize(activity, id_only: true)

    additional =
      Transmogrifier.prepare_object(activity.data, Map.get(opts, :host))
      |> Map.put("object", object_id)

    Map.merge(base, additional)
  end
end
