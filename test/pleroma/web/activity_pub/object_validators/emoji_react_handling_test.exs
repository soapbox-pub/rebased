# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.EmojiReactHandlingTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "EmojiReacts" do
    setup do
      user = insert(:user)
      {:ok, post_activity} = CommonAPI.post(user, %{status: "uguu"})

      object = Pleroma.Object.get_by_ap_id(post_activity.data["object"])

      {:ok, valid_emoji_react, []} = Builder.emoji_react(user, object, "👌")

      %{user: user, post_activity: post_activity, valid_emoji_react: valid_emoji_react}
    end

    test "it validates a valid EmojiReact", %{valid_emoji_react: valid_emoji_react} do
      assert {:ok, _, _} = ObjectValidator.validate(valid_emoji_react, [])
    end

    test "it is not valid without a 'content' field", %{valid_emoji_react: valid_emoji_react} do
      without_content =
        valid_emoji_react
        |> Map.delete("content")

      {:error, cng} = ObjectValidator.validate(without_content, [])

      refute cng.valid?
      assert {:content, {"can't be blank", [validation: :required]}} in cng.errors
    end

    test "it is not valid with a non-emoji content field", %{valid_emoji_react: valid_emoji_react} do
      without_emoji_content =
        valid_emoji_react
        |> Map.put("content", "x")

      {:error, cng} = ObjectValidator.validate(without_emoji_content, [])

      refute cng.valid?

      assert {:content, {"must be a single character emoji", []}} in cng.errors
    end
  end
end
