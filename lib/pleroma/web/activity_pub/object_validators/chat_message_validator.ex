# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.ChatMessageValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ObjectValidators.AttachmentValidator

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.Transmogrifier, only: [fix_emoji: 1]

  @primary_key false
  @derive Jason.Encoder

  embedded_schema do
    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:to, ObjectValidators.Recipients, default: [])
    field(:type, :string)
    field(:content, ObjectValidators.SafeText)
    field(:actor, ObjectValidators.ObjectID)
    field(:published, ObjectValidators.DateTime)
    field(:emoji, ObjectValidators.Emoji, default: %{})

    embeds_one(:attachment, AttachmentValidator)
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
    |> fix_attachment()
    |> Map.put_new("actor", data["attributedTo"])
  end

  # Throws everything but the first one away
  def fix_attachment(%{"attachment" => [attachment | _]} = data) do
    data
    |> Map.put("attachment", attachment)
  end

  def fix_attachment(data), do: data

  def changeset(struct, data) do
    data = fix(data)

    struct
    |> cast(data, List.delete(__schema__(:fields), :attachment))
    |> cast_embed(:attachment)
  end

  defp validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["ChatMessage"])
    |> validate_required([:id, :actor, :to, :type, :published])
    |> validate_content_or_attachment()
    |> validate_length(:to, is: 1)
    |> validate_length(:content, max: Pleroma.Config.get([:instance, :remote_limit]))
    |> validate_local_concern()
  end

  def validate_content_or_attachment(cng) do
    attachment = get_field(cng, :attachment)

    if attachment do
      cng
    else
      cng
      |> validate_required([:content])
    end
  end

  @doc """
  Validates the following
  - If both users are in our system
  - If at least one of the users in this ChatMessage is a local user
  - If the recipient is not blocking the actor
  - If the recipient is explicitly not accepting chat messages
  """
  def validate_local_concern(cng) do
    with actor_ap <- get_field(cng, :actor),
         {_, %User{} = actor} <- {:find_actor, User.get_cached_by_ap_id(actor_ap)},
         {_, %User{} = recipient} <-
           {:find_recipient, User.get_cached_by_ap_id(get_field(cng, :to) |> hd())},
         {_, false} <- {:not_accepting_chats?, recipient.accepts_chat_messages == false},
         {_, false} <- {:blocking_actor?, User.blocks?(recipient, actor)},
         {_, true} <- {:local?, Enum.any?([actor, recipient], & &1.local)} do
      cng
    else
      {:blocking_actor?, true} ->
        cng
        |> add_error(:actor, "actor is blocked by recipient")

      {:not_accepting_chats?, true} ->
        cng
        |> add_error(:to, "recipient does not accept chat messages")

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
