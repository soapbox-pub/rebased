# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.CommonFields do
  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Web.ActivityPub.ObjectValidators.AttachmentValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.TagValidator

  # Activities and Objects, except (Create)ChatMessage
  defmacro message_fields do
    quote bind_quoted: binding() do
      field(:type, :string)
      field(:id, ObjectValidators.ObjectID, primary_key: true)

      field(:to, ObjectValidators.Recipients, default: [])
      field(:cc, ObjectValidators.Recipients, default: [])
      field(:bto, ObjectValidators.Recipients, default: [])
      field(:bcc, ObjectValidators.Recipients, default: [])
    end
  end

  defmacro activity_fields do
    quote bind_quoted: binding() do
      field(:object, ObjectValidators.ObjectID)
      field(:actor, ObjectValidators.ObjectID)
    end
  end

  # All objects except Answer and CHatMessage
  defmacro object_fields do
    quote bind_quoted: binding() do
      field(:content, :string)

      field(:published, ObjectValidators.DateTime)
      field(:updated, ObjectValidators.DateTime)
      field(:emoji, ObjectValidators.Emoji, default: %{})
      embeds_many(:attachment, AttachmentValidator)
    end
  end

  # Basically objects that aren't ChatMessage and Answer
  defmacro status_object_fields do
    quote bind_quoted: binding() do
      # TODO: Remove actor on objects
      field(:actor, ObjectValidators.ObjectID)
      field(:attributedTo, ObjectValidators.ObjectID)

      embeds_many(:tag, TagValidator)

      field(:name, :string)
      field(:summary, :string)

      field(:context, :string)

      field(:sensitive, :boolean, default: false)
      field(:replies_count, :integer, default: 0)
      field(:like_count, :integer, default: 0)
      field(:announcement_count, :integer, default: 0)
      field(:inReplyTo, ObjectValidators.ObjectID)
      field(:url, ObjectValidators.Uri)

      field(:likes, {:array, ObjectValidators.ObjectID}, default: [])
      field(:announcements, {:array, ObjectValidators.ObjectID}, default: [])
    end
  end
end
