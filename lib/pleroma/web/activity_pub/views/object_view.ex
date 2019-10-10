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

  def render("object.json", %{object: %Activity{data: %{"type" => activity_type}} = activity})
      when activity_type in ["Create", "Listen"] do
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
end
