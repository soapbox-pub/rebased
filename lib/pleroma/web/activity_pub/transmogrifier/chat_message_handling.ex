# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.ChatMessageHandling do
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.ChatMessageValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.CreateChatMessageValidator
  alias Pleroma.Web.ActivityPub.Pipeline

  def handle_incoming(
        %{"type" => "Create", "object" => %{"type" => "ChatMessage"} = object_data} = data,
        _options
      ) do
    with {_, {:ok, cast_data_sym}} <-
           {:casting_data, data |> CreateChatMessageValidator.cast_and_apply()},
         cast_data = ObjectValidator.stringify_keys(cast_data_sym),
         {_, {:ok, object_cast_data_sym}} <-
           {:casting_object_data, object_data |> ChatMessageValidator.cast_and_apply()},
         object_cast_data = ObjectValidator.stringify_keys(object_cast_data_sym),
         {_, {:ok, validated_object, _meta}} <-
           {:validate_object, ObjectValidator.validate(object_cast_data, %{})},
         {_, {:ok, _created_object}} <- {:persist_object, Object.create(validated_object)},
         {_, {:ok, activity, _meta}} <-
           {:common_pipeline, Pipeline.common_pipeline(cast_data, local: false)} do
      {:ok, activity}
    else
      e ->
        {:error, e}
    end
  end
end
