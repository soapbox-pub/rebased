# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.SafeTextTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.EctoType.ActivityPub.ObjectValidators.SafeText

  test "it lets normal text go through" do
    text = "hey how are you"
    assert {:ok, text} == SafeText.cast(text)
  end

  test "it removes html tags from text" do
    text = "hey look xss <script>alert('foo')</script>"
    assert {:ok, "hey look xss alert(&#39;foo&#39;)"} == SafeText.cast(text)
  end

  test "it keeps basic html tags" do
    text = "hey <a href='http://gensokyo.2hu'>look</a> xss <script>alert('foo')</script>"

    assert {:ok, "hey <a href=\"http://gensokyo.2hu\">look</a> xss alert(&#39;foo&#39;)"} ==
             SafeText.cast(text)
  end

  test "errors for non-text" do
    assert :error == SafeText.cast(1)
  end
end
