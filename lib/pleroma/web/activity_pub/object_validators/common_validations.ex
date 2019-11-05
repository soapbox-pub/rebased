# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations do
  import Ecto.Changeset

  alias Pleroma.Object
  alias Pleroma.User

  def validate_actor_presence(cng, field_name \\ :actor) do
    cng
    |> validate_change(field_name, fn field_name, actor ->
      if User.get_cached_by_ap_id(actor) do
        []
      else
        [{field_name, "can't find user"}]
      end
    end)
  end

  def validate_object_presence(cng, field_name \\ :object) do
    cng
    |> validate_change(field_name, fn field_name, actor ->
      if Object.get_cached_by_ap_id(actor) do
        []
      else
        [{field_name, "can't find user"}]
      end
    end)
  end
end
