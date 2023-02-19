# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidator do
  @moduledoc """
  This module is responsible for validating an object (which can be an activity)
  and checking if it is both well formed and also compatible with our view of
  the system.
  """

  @behaviour Pleroma.Web.ActivityPub.ObjectValidator.Validating

  alias Pleroma.Activity
  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Object
  alias Pleroma.Object.Containment
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ObjectValidators.AcceptRejectValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.AddRemoveValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.AnnounceValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.AnswerValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.ArticleNotePageValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.AudioVideoValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.BlockValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.ChatMessageValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.CreateChatMessageValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.CreateGenericValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.DeleteValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.EmojiReactValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.EventValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.FollowValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.LikeValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.QuestionValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.UndoValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.UpdateValidator

  @impl true
  def validate(object, meta)

  def validate(%{"type" => "Block"} = block_activity, meta) do
    with {:ok, block_activity} <-
           block_activity
           |> BlockValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      block_activity = stringify_keys(block_activity)
      outgoing_blocks = Pleroma.Config.get([:activitypub, :outgoing_blocks])

      meta =
        if !outgoing_blocks do
          Keyword.put(meta, :do_not_federate, true)
        else
          meta
        end

      {:ok, block_activity, meta}
    end
  end

  def validate(%{"type" => "Undo"} = object, meta) do
    with {:ok, object} <-
           object
           |> UndoValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      undone_object = Activity.get_by_ap_id(object["object"])

      meta =
        meta
        |> Keyword.put(:object_data, undone_object.data)

      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "Delete"} = object, meta) do
    with cng <- DeleteValidator.cast_and_validate(object),
         do_not_federate <- DeleteValidator.do_not_federate?(cng),
         {:ok, object} <- Ecto.Changeset.apply_action(cng, :insert) do
      object = stringify_keys(object)
      meta = Keyword.put(meta, :do_not_federate, do_not_federate)
      {:ok, object, meta}
    end
  end

  def validate(
        %{"type" => "Create", "object" => %{"type" => "ChatMessage"} = object} = create_activity,
        meta
      ) do
    with {:ok, object_data} <- cast_and_apply(object),
         meta = Keyword.put(meta, :object_data, object_data |> stringify_keys),
         {:ok, create_activity} <-
           create_activity
           |> CreateChatMessageValidator.cast_and_validate(meta)
           |> Ecto.Changeset.apply_action(:insert) do
      create_activity = stringify_keys(create_activity)
      {:ok, create_activity, meta}
    end
  end

  def validate(
        %{"type" => "Create", "object" => %{"type" => objtype} = object} = create_activity,
        meta
      )
      when objtype in ~w[Question Answer Audio Video Event Article Note Page] do
    with {:ok, object_data} <- cast_and_apply_and_stringify_with_history(object),
         meta = Keyword.put(meta, :object_data, object_data),
         {:ok, create_activity} <-
           create_activity
           |> CreateGenericValidator.cast_and_validate(meta)
           |> Ecto.Changeset.apply_action(:insert) do
      create_activity = stringify_keys(create_activity)
      {:ok, create_activity, meta}
    end
  end

  def validate(%{"type" => type} = object, meta)
      when type in ~w[Event Question Audio Video Article Note Page] do
    validator =
      case type do
        "Event" -> EventValidator
        "Question" -> QuestionValidator
        "Audio" -> AudioVideoValidator
        "Video" -> AudioVideoValidator
        "Article" -> ArticleNotePageValidator
        "Note" -> ArticleNotePageValidator
        "Page" -> ArticleNotePageValidator
      end

    with {:ok, object} <-
           do_separate_with_history(object, fn object ->
             with {:ok, object} <-
                    object
                    |> validator.cast_and_validate()
                    |> Ecto.Changeset.apply_action(:insert) do
               object = stringify_keys(object)

               # Insert copy of hashtags as strings for the non-hashtag table indexing
               tag = (object["tag"] || []) ++ Object.hashtags(%Object{data: object})
               object = Map.put(object, "tag", tag)

               {:ok, object}
             end
           end) do
      {:ok, object, meta}
    end
  end

  def validate(
        %{"type" => "Update", "object" => %{"type" => objtype} = object} = update_activity,
        meta
      )
      when objtype in ~w[Question Answer Audio Video Event Article Note Page] do
    with {_, false} <- {:local, Access.get(meta, :local, false)},
         {_, {:ok, object_data, _}} <- {:object_validation, validate(object, meta)},
         meta = Keyword.put(meta, :object_data, object_data),
         {:ok, update_activity} <-
           update_activity
           |> UpdateValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      update_activity = stringify_keys(update_activity)
      {:ok, update_activity, meta}
    else
      {:local, _} ->
        with {:ok, object} <-
               update_activity
               |> UpdateValidator.cast_and_validate()
               |> Ecto.Changeset.apply_action(:insert) do
          object = stringify_keys(object)
          {:ok, object, meta}
        end

      {:object_validation, e} ->
        e
    end
  end

  def validate(%{"type" => type} = object, meta)
      when type in ~w[Accept Reject Follow Update Like EmojiReact Announce
      ChatMessage Answer] do
    validator =
      case type do
        "Accept" -> AcceptRejectValidator
        "Reject" -> AcceptRejectValidator
        "Follow" -> FollowValidator
        "Update" -> UpdateValidator
        "Like" -> LikeValidator
        "EmojiReact" -> EmojiReactValidator
        "Announce" -> AnnounceValidator
        "ChatMessage" -> ChatMessageValidator
        "Answer" -> AnswerValidator
      end

    with {:ok, object} <-
           object
           |> validator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => type} = object, meta) when type in ~w(Add Remove) do
    with {:ok, object} <-
           object
           |> AddRemoveValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      {:ok, object, meta}
    end
  end

  def validate(o, m), do: {:error, {:validator_not_set, {o, m}}}

  def cast_and_apply_and_stringify_with_history(object) do
    do_separate_with_history(object, fn object ->
      with {:ok, object_data} <- cast_and_apply(object),
           object_data <- object_data |> stringify_keys() do
        {:ok, object_data}
      end
    end)
  end

  def cast_and_apply(%{"type" => "ChatMessage"} = object) do
    ChatMessageValidator.cast_and_apply(object)
  end

  def cast_and_apply(%{"type" => "Question"} = object) do
    QuestionValidator.cast_and_apply(object)
  end

  def cast_and_apply(%{"type" => "Answer"} = object) do
    AnswerValidator.cast_and_apply(object)
  end

  def cast_and_apply(%{"type" => type} = object) when type in ~w[Audio Video] do
    AudioVideoValidator.cast_and_apply(object)
  end

  def cast_and_apply(%{"type" => "Event"} = object) do
    EventValidator.cast_and_apply(object)
  end

  def cast_and_apply(%{"type" => type} = object) when type in ~w[Article Note Page] do
    ArticleNotePageValidator.cast_and_apply(object)
  end

  def cast_and_apply(o), do: {:error, {:validator_not_set, o}}

  def stringify_keys(object) when is_struct(object) do
    object
    |> Map.from_struct()
    |> stringify_keys
  end

  def stringify_keys(object) when is_map(object) do
    object
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Map.new(fn {key, val} -> {to_string(key), stringify_keys(val)} end)
  end

  def stringify_keys(object) when is_list(object) do
    object
    |> Enum.map(&stringify_keys/1)
  end

  def stringify_keys(object), do: object

  def fetch_actor(object) do
    with actor <- Containment.get_actor(object),
         {:ok, actor} <- ObjectValidators.ObjectID.cast(actor) do
      User.get_or_fetch_by_ap_id(actor)
    end
  end

  def fetch_actor_and_object(object) do
    fetch_actor(object)
    Object.normalize(object["object"], fetch: true)
    :ok
  end

  defp for_each_history_item(
         %{"type" => "OrderedCollection", "orderedItems" => items} = history,
         object,
         fun
       ) do
    processed_items =
      Enum.map(items, fn item ->
        with item <- Map.put(item, "id", object["id"]),
             {:ok, item} <- fun.(item) do
          item
        else
          _ -> nil
        end
      end)

    if Enum.all?(processed_items, &(not is_nil(&1))) do
      {:ok, Map.put(history, "orderedItems", processed_items)}
    else
      {:error, :invalid_history}
    end
  end

  defp for_each_history_item(nil, _object, _fun) do
    {:ok, nil}
  end

  defp for_each_history_item(_, _object, _fun) do
    {:error, :invalid_history}
  end

  # fun is (object -> {:ok, validated_object_with_string_keys})
  defp do_separate_with_history(object, fun) do
    with history <- object["formerRepresentations"],
         object <- Map.drop(object, ["formerRepresentations"]),
         {_, {:ok, object}} <- {:main_body, fun.(object)},
         {_, {:ok, history}} <- {:history_items, for_each_history_item(history, object, fun)} do
      object =
        if history do
          Map.put(object, "formerRepresentations", history)
        else
          object
        end

      {:ok, object}
    else
      {:main_body, e} -> e
      {:history_items, e} -> e
    end
  end
end
