# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes do
  alias Pleroma.Object.Containment
  alias Pleroma.Web.ActivityPub.Utils

  # based on Pleroma.Web.ActivityPub.Utils.lazy_put_objects_defaults
  def fix_defaults(data) do
    %{data: %{"id" => context}, id: context_id} =
      Utils.create_context(data["context"] || data["conversation"])

    data
    |> Map.put("context", context)
    |> Map.put("context_id", context_id)
  end

  def fix_attribution(data) do
    data
    |> Map.put_new("actor", data["attributedTo"])
  end

  def fix_actor(data) do
    actor = Containment.get_actor(data)

    data
    |> Map.put("actor", actor)
    |> Map.put("attributedTo", actor)
  end
end
