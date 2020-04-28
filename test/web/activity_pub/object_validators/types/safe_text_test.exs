# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.Types.SafeTextTest do
  use Pleroma.DataCase

  alias Pleroma.Web.ActivityPub.ObjectValidators.Types.SafeText

  test "it lets normal text go through" do
    text = "hey how are you"
    assert {:ok, text} == SafeText.cast(text)
  end

  test "it removes html tags from text" do
    text = "hey look xss <script>alert('foo')</script>"
    assert {:ok, "hey look xss alert(&#39;foo&#39;)"} == SafeText.cast(text)
  end

  test "errors for non-text" do
    assert :error == SafeText.cast(1)
  end
end
