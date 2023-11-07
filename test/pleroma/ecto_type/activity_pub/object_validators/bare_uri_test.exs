# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.BareUriTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.EctoType.ActivityPub.ObjectValidators.BareUri

  test "diaspora://" do
    text = "diaspora://alice@fediverse.example/post/deadbeefdeadbeefdeadbeefdeadbeef"
    assert {:ok, ^text} = BareUri.cast(text)
  end

  test "nostr:" do
    text = "nostr:note1gwdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
    assert {:ok, ^text} = BareUri.cast(text)
  end

  test "errors for non-URIs" do
    assert :error == BareUri.cast(1)
    assert :error == BareUri.cast("foo")
    assert :error == BareUri.cast("foo bar")
  end
end
