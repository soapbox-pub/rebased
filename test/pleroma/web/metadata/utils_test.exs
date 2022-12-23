# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.UtilsTest do
  use Pleroma.DataCase, async: false
  import Pleroma.Factory
  alias Pleroma.Web.Metadata.Utils

  describe "scrub_html_and_truncate/1" do
    test "it returns content text without encode HTML if summary is nil" do
      user = insert(:user)

      note =
        insert(:note, %{
          data: %{
            "actor" => user.ap_id,
            "id" => "https://pleroma.gov/objects/whatever",
            "summary" => nil,
            "content" => "Pleroma's really cool!"
          }
        })

      assert Utils.scrub_html_and_truncate(note) == "Pleroma's really cool!"
    end

    test "it returns context text without encode HTML if summary is empty" do
      user = insert(:user)

      note =
        insert(:note, %{
          data: %{
            "actor" => user.ap_id,
            "id" => "https://pleroma.gov/objects/whatever",
            "summary" => "",
            "content" => "Pleroma's really cool!"
          }
        })

      assert Utils.scrub_html_and_truncate(note) == "Pleroma's really cool!"
    end

    test "it returns summary text without encode HTML if summary is filled" do
      user = insert(:user)

      note =
        insert(:note, %{
          data: %{
            "actor" => user.ap_id,
            "id" => "https://pleroma.gov/objects/whatever",
            "summary" => "Public service announcement on caffeine consumption",
            "content" => "cofe"
          }
        })

      assert Utils.scrub_html_and_truncate(note) ==
               "Public service announcement on caffeine consumption"
    end

    test "it does not return old content after editing" do
      user = insert(:user)

      {:ok, activity} = Pleroma.Web.CommonAPI.post(user, %{status: "mew mew #def"})

      object = Pleroma.Object.normalize(activity)
      assert Utils.scrub_html_and_truncate(object) == "mew mew #def"

      {:ok, update} = Pleroma.Web.CommonAPI.update(user, activity, %{status: "mew mew #abc"})
      update = Pleroma.Activity.normalize(update)
      object = Pleroma.Object.normalize(update)
      assert Utils.scrub_html_and_truncate(object) == "mew mew #abc"
    end
  end

  describe "scrub_html_and_truncate/2" do
    test "it returns text without encode HTML" do
      assert Utils.scrub_html_and_truncate("Pleroma's really cool!") == "Pleroma's really cool!"
    end
  end
end
