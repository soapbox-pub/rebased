# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.ChatMessageValidator do
  use Ecto.Schema

  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ObjectValidators.Types

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.Transmogrifier, only: [fix_emoji: 1]

  @primary_key false
  @derive Jason.Encoder

  embedded_schema do
    field(:id, Types.ObjectID, primary_key: true)
    field(:to, Types.Recipients, default: [])
    field(:type, :string)
    field(:content, Types.SafeText)
    field(:actor, Types.ObjectID)
    field(:published, Types.DateTime)
    field(:emoji, :map, default: %{})
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
    |> fix_emoji()
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
    |> validate_required([:id, :actor, :to, :type, :content, :published])
    |> validate_length(:to, is: 1)
    |> validate_length(:content, max: Pleroma.Config.get([:instance, :remote_limit]))
    |> validate_local_concern()
  end

  @doc """
  Validates the following
  - If both users are in our system
  - If at least one of the users in this ChatMessage is a local user
  - If the recipient is not blocking the actor
  """
  def validate_local_concern(cng) do
    with actor_ap <- get_field(cng, :actor),
         {_, %User{} = actor} <- {:find_actor, User.get_cached_by_ap_id(actor_ap)},
         {_, %User{} = recipient} <-
           {:find_recipient, User.get_cached_by_ap_id(get_field(cng, :to) |> hd())},
         {_, false} <- {:blocking_actor?, User.blocks?(recipient, actor)},
         {_, true} <- {:local?, Enum.any?([actor, recipient], & &1.local)} do
      cng
    else
      {:blocking_actor?, true} ->
        cng
        |> add_error(:actor, "actor is blocked by recipient")

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
