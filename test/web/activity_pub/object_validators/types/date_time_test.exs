defmodule Pleroma.Web.ActivityPub.ObjectValidators.Types.DateTimeTest do
  alias Pleroma.Web.ActivityPub.ObjectValidators.Types.DateTime
  use Pleroma.DataCase

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
