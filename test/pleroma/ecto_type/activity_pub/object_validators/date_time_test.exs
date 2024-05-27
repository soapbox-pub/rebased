# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.DateTimeTest do
  alias Pleroma.EctoType.ActivityPub.ObjectValidators.DateTime
  use Pleroma.DataCase, async: true

  test "it validates an xsd:Datetime" do
    valid_strings = [
      "2004-04-12T13:20:00",
      "2004-04-12T13:20:15.5",
      "2004-04-12T13:20:00-05:00",
      "2004-04-12T13:20:00Z"
    ]

    invalid_strings = [
      "2004-04-12T13:00",
      "2004-04-1213:20:00",
      "99-04-12T13:00",
      "2004-04-12"
    ]

    assert {:ok, "2004-04-01T12:00:00Z"} == DateTime.cast("2004-04-01T12:00:00Z")

    Enum.each(valid_strings, fn date_time ->
      result = DateTime.cast(date_time)
      assert {:ok, _} = result
    end)

    Enum.each(invalid_strings, fn date_time ->
      result = DateTime.cast(date_time)
      assert :error == result
    end)
  end
end
