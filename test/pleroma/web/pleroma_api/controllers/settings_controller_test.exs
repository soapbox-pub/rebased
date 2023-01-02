# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.SettingsControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  describe "GET /api/v1/pleroma/settings/:app" do
    setup do
      oauth_access(["read:accounts"])
    end

    test "it gets empty settings", %{conn: conn} do
      response =
        conn
        |> get("/api/v1/pleroma/settings/pleroma-fe")
        |> json_response_and_validate_schema(:ok)

      assert response == %{}
    end

    test "it gets settings", %{conn: conn, user: user} do
      response =
        conn
        |> assign(
          :user,
          struct(user,
            pleroma_settings_store: %{
              "pleroma-fe" => %{
                "foo" => "bar"
              }
            }
          )
        )
        |> get("/api/v1/pleroma/settings/pleroma-fe")
        |> json_response_and_validate_schema(:ok)

      assert %{"foo" => "bar"} == response
    end
  end

  describe "POST /api/v1/pleroma/settings/:app" do
    setup do
      settings = %{
        "foo" => "bar",
        "nested" => %{
          "1" => "2"
        }
      }

      user =
        insert(
          :user,
          %{
            pleroma_settings_store: %{
              "pleroma-fe" => settings
            }
          }
        )

      %{conn: conn} = oauth_access(["write:accounts"], user: user)

      %{conn: conn, user: user, settings: settings}
    end

    test "it adds keys", %{conn: conn} do
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/v1/pleroma/settings/pleroma-fe", %{
          "foo" => "edited",
          "bar" => "new",
          "nested" => %{"3" => "4"}
        })
        |> json_response_and_validate_schema(:ok)

      assert response == %{
               "foo" => "edited",
               "bar" => "new",
               "nested" => %{
                 "1" => "2",
                 "3" => "4"
               }
             }
    end

    test "it removes keys", %{conn: conn} do
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/v1/pleroma/settings/pleroma-fe", %{
          "foo" => nil,
          "bar" => nil,
          "nested" => %{
            "1" => nil,
            "3" => nil
          }
        })
        |> json_response_and_validate_schema(:ok)

      assert response == %{
               "nested" => %{}
             }
    end

    test "it does not override settings for other apps", %{
      conn: conn,
      user: user,
      settings: settings
    } do
      conn
      |> put_req_header("content-type", "application/json")
      |> patch("/api/v1/pleroma/settings/admin-fe", %{"foo" => "bar"})
      |> json_response_and_validate_schema(:ok)

      user = Pleroma.User.get_by_id(user.id)

      assert user.pleroma_settings_store == %{
               "pleroma-fe" => settings,
               "admin-fe" => %{"foo" => "bar"}
             }
    end
  end
end
