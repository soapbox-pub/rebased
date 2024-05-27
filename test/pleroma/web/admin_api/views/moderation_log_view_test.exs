# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.AdminAPI.ModerationLogViewTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.AdminAPI.ModerationLogView

  describe "renders `report_note_delete` log messages" do
    setup do
      log1 = %Pleroma.ModerationLog{
        id: 1,
        data: %{
          "action" => "report_note_delete",
          "actor" => %{"id" => "A1I7G8", "nickname" => "admin", "type" => "user"},
          "message" => "@admin deleted note 'mistake' from report #A1I7be on user @b-612",
          "subject" => %{"id" => "A1I7be", "state" => "open", "type" => "report"},
          "subject_actor" => %{"id" => "A1I7G8", "nickname" => "b-612", "type" => "user"},
          "text" => "mistake"
        },
        inserted_at: ~N[2020-11-17 14:13:20]
      }

      log2 = %Pleroma.ModerationLog{
        id: 2,
        data: %{
          "action" => "report_note_delete",
          "actor" => %{"id" => "A1I7G8", "nickname" => "admin", "type" => "user"},
          "message" => "@admin deleted note 'fake user' from report #A1I7be on user @j-612",
          "subject" => %{"id" => "A1I7be", "state" => "open", "type" => "report"},
          "subject_actor" => %{"id" => "A1I7G8", "nickname" => "j-612", "type" => "user"},
          "text" => "fake user"
        },
        inserted_at: ~N[2020-11-17 14:13:20]
      }

      {:ok, %{log1: log1, log2: log2}}
    end

    test "renders `report_note_delete` log messages", %{log1: log1, log2: log2} do
      assert ModerationLogView.render(
               "index.json",
               %{log: %{items: [log1, log2], count: 2}}
             ) == %{
               items: [
                 %{
                   id: 1,
                   data: %{
                     "action" => "report_note_delete",
                     "actor" => %{"id" => "A1I7G8", "nickname" => "admin", "type" => "user"},
                     "message" =>
                       "@admin deleted note 'mistake' from report #A1I7be on user @b-612",
                     "subject" => %{"id" => "A1I7be", "state" => "open", "type" => "report"},
                     "subject_actor" => %{
                       "id" => "A1I7G8",
                       "nickname" => "b-612",
                       "type" => "user"
                     },
                     "text" => "mistake"
                   },
                   message: "@admin deleted note 'mistake' from report #A1I7be on user @b-612",
                   time: 1_605_622_400
                 },
                 %{
                   id: 2,
                   data: %{
                     "action" => "report_note_delete",
                     "actor" => %{"id" => "A1I7G8", "nickname" => "admin", "type" => "user"},
                     "message" =>
                       "@admin deleted note 'fake user' from report #A1I7be on user @j-612",
                     "subject" => %{"id" => "A1I7be", "state" => "open", "type" => "report"},
                     "subject_actor" => %{
                       "id" => "A1I7G8",
                       "nickname" => "j-612",
                       "type" => "user"
                     },
                     "text" => "fake user"
                   },
                   message: "@admin deleted note 'fake user' from report #A1I7be on user @j-612",
                   time: 1_605_622_400
                 }
               ],
               total: 2
             }
    end

    test "renders `report_note_delete` log message", %{log1: log} do
      assert ModerationLogView.render("show.json", %{log_entry: log}) == %{
               id: 1,
               data: %{
                 "action" => "report_note_delete",
                 "actor" => %{"id" => "A1I7G8", "nickname" => "admin", "type" => "user"},
                 "message" => "@admin deleted note 'mistake' from report #A1I7be on user @b-612",
                 "subject" => %{"id" => "A1I7be", "state" => "open", "type" => "report"},
                 "subject_actor" => %{"id" => "A1I7G8", "nickname" => "b-612", "type" => "user"},
                 "text" => "mistake"
               },
               message: "@admin deleted note 'mistake' from report #A1I7be on user @b-612",
               time: 1_605_622_400
             }
    end
  end
end
