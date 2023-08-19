# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.EventValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations
  alias Pleroma.Web.ActivityPub.ObjectValidators.PlaceValidator
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Ecto.Changeset

  @primary_key false
  @derive Jason.Encoder

  # Extends from NoteValidator
  embedded_schema do
    quote do
      unquote do
        import Elixir.Pleroma.Web.ActivityPub.ObjectValidators.CommonFields
        message_fields()
        object_fields()
        status_object_fields()
      end
    end

    field(:startTime, ObjectValidators.DateTime)
    field(:endTime, ObjectValidators.DateTime)

    field(:joinMode, :string, default: "free")

    embeds_one(:location, PlaceValidator)

    field(:participation_count, :integer, default: 0)
    field(:participations, {:array, ObjectValidators.ObjectID}, default: [])
    field(:participation_request_count, :integer, default: 0)
  end

  def cast_and_apply(data, meta \\ []) do
    data
    |> cast_data(meta)
    |> apply_action(:insert)
  end

  def cast_and_validate(data, meta \\ []) do
    data
    |> cast_data(meta)
    |> validate_data()
  end

  def cast_data(data, meta \\ []) do
    %__MODULE__{}
    |> changeset(data, meta)
  end

  defp fix(data, meta) do
    data
    |> CommonFixes.fix_actor()
    |> CommonFixes.fix_object_defaults()
    |> Transmogrifier.fix_emoji()
    |> CommonFixes.maybe_add_language(meta)
    |> CommonFixes.maybe_add_content_map()
  end

  def changeset(struct, data, meta \\ []) do
    data = fix(data, meta)

    struct
    |> cast(data, __schema__(:fields) -- [:attachment, :tag, :location])
    |> cast_embed(:attachment)
    |> cast_embed(:tag)
    |> cast_embed(:location)
  end

  defp validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["Event"])
    |> validate_inclusion(:joinMode, ~w[free restricted invite])
    |> validate_required([:id, :actor, :attributedTo, :type, :context])
    |> CommonValidations.validate_any_presence([:cc, :to])
    |> CommonValidations.validate_fields_match([:actor, :attributedTo])
    |> CommonValidations.validate_actor_presence()
    |> CommonValidations.validate_host_match()
  end
end
