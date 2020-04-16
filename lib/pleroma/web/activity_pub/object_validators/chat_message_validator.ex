# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.ChatMessageValidator do
  use Ecto.Schema

  alias Pleroma.Web.ActivityPub.ObjectValidators.Types
  alias Pleroma.User

  import Ecto.Changeset

  @primary_key false
  @derive Jason.Encoder

  embedded_schema do
    field(:id, Types.ObjectID, primary_key: true)
    field(:to, Types.Recipients, default: [])
    field(:type, :string)
    field(:content, :string)
    field(:actor, Types.ObjectID)
    field(:published, Types.DateTime)
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

  def fix(data) do
    data
    |> Map.put_new("actor", data["attributedTo"])
  end

  def changeset(struct, data) do
    data = fix(data)

    struct
    |> cast(data, __schema__(:fields))
  end

  def validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["ChatMessage"])
    |> validate_required([:id, :actor, :to, :type, :content])
    |> validate_length(:to, is: 1)
    |> validate_local_concern()
  end

  @doc "Validates if at least one of the users in this ChatMessage is a local user, otherwise we don't want the message in our system. It also validates the presence of both users in our system."
  def validate_local_concern(cng) do
    with actor_ap <- get_field(cng, :actor),
         {_, %User{} = actor} <- {:find_actor, User.get_cached_by_ap_id(actor_ap)},
         {_, %User{} = recipient} <-
           {:find_recipient, User.get_cached_by_ap_id(get_field(cng, :to) |> hd())},
         {_, true} <- {:local?, Enum.any?([actor, recipient], & &1.local)} do
      cng
    else
      {:local?, false} ->
        cng
        |> add_error(:actor, "actor and recipient are both remote")

      {:find_actor, _} ->
        cng
        |> add_error(:actor, "can't find user")

      {:find_recipient, _} ->
        cng
        |> add_error(:to, "can't find user")
    end
  end
end
