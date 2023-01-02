# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ReportNoteTest do
  alias Pleroma.ReportNote
  use Pleroma.DataCase, async: true
  import Pleroma.Factory

  test "create/3" do
    user = insert(:user)
    report = insert(:report_activity)
    assert {:ok, note} = ReportNote.create(user.id, report.id, "naughty boy")
    assert note.content == "naughty boy"
  end

  test "create/3 with very long content" do
    user = insert(:user)
    report = insert(:report_activity)

    very_long_content = """
    ] pwgen 25 15
    eJ9eeceiquoolei2queeLeimi aiN9ie2iokie8chush7aiph5N ulaNgaighoPiequaipuzoog8F
    Ohphei0hee6hoo0wah4Aasah9 ziel3Yo3eew4neiy3ekiesh8u ue9ShahTh7oongoPheeneijah
    ohGheeCh6aloque0Neviopou3 ush2oobohxeec4aequeich3Oo Ze3eighoowiojadohch8iCa1n
    Yu4yieBie9eengoich8fae4th chohqu6exooSiibogh3iefeez peephahtaik9quie5mohD9nee
    eeQuur3rie5mei8ieng6iesie wei1meinguv0Heidoov8Ibaed deemo2Poh6ohc3eiBeez1uox2
    ] pwgen 25 15
    eJ9eeceiquoolei2queeLeimi aiN9ie2iokie8chush7aiph5N ulaNgaighoPiequaipuzoog8F
    Ohphei0hee6hoo0wah4Aasah9 ziel3Yo3eew4neiy3ekiesh8u ue9ShahTh7oongoPheeneijah
    ohGheeCh6aloque0Neviopou3 ush2oobohxeec4aequeich3Oo Ze3eighoowiojadohch8iCa1n
    Yu4yieBie9eengoich8fae4th chohqu6exooSiibogh3iefeez peephahtaik9quie5mohD9nee
    eeQuur3rie5mei8ieng6iesie wei1meinguv0Heidoov8Ibaed deemo2Poh6ohc3eiBeez1uox2
    """

    assert {:ok, note} = ReportNote.create(user.id, report.id, very_long_content)
    assert note.content == very_long_content
  end
end
