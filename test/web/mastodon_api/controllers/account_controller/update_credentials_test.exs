# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MastodonAPIController.UpdateCredentialsTest do
  alias Pleroma.Repo
  alias Pleroma.User

  use Pleroma.Web.ConnCase

  import Pleroma.Factory
  clear_config([:instance, :max_account_fields])

  describe "updating credentials" do
    setup do: oauth_access(["write:accounts"])

    test "sets user settings in a generic way", %{conn: conn} do
      res_conn =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          "pleroma_settings_store" => %{
            pleroma_fe: %{
              theme: "bla"
            }
          }
        })

      assert user_data = json_response(res_conn, 200)
      assert user_data["pleroma"]["settings_store"] == %{"pleroma_fe" => %{"theme" => "bla"}}

      user = Repo.get(User, user_data["id"])

      res_conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{
          "pleroma_settings_store" => %{
            masto_fe: %{
              theme: "bla"
            }
          }
        })

      assert user_data = json_response(res_conn, 200)

      assert user_data["pleroma"]["settings_store"] ==
               %{
                 "pleroma_fe" => %{"theme" => "bla"},
                 "masto_fe" => %{"theme" => "bla"}
               }

      user = Repo.get(User, user_data["id"])

      res_conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{
          "pleroma_settings_store" => %{
            masto_fe: %{
              theme: "blub"
            }
          }
        })

      assert user_data = json_response(res_conn, 200)

      assert user_data["pleroma"]["settings_store"] ==
               %{
                 "pleroma_fe" => %{"theme" => "bla"},
                 "masto_fe" => %{"theme" => "blub"}
               }
    end

    test "updates the user's bio", %{conn: conn} do
      user2 = insert(:user)

      conn =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          "note" => "I drink #cofe with @#{user2.nickname}"
        })

      assert user_data = json_response(conn, 200)

      assert user_data["note"] ==
               ~s(I drink <a class="hashtag" data-tag="cofe" href="http://localhost:4001/tag/cofe">#cofe</a> with <span class="h-card"><a data-user="#{
                 user2.id
               }" class="u-url mention" href="#{user2.ap_id}" rel="ugc">@<span>#{user2.nickname}</span></a></span>)
    end

    test "updates the user's locking status", %{conn: conn} do
      conn = patch(conn, "/api/v1/accounts/update_credentials", %{locked: "true"})

      assert user_data = json_response(conn, 200)
      assert user_data["locked"] == true
    end

    test "updates the user's allow_following_move", %{user: user, conn: conn} do
      assert user.allow_following_move == true

      conn = patch(conn, "/api/v1/accounts/update_credentials", %{allow_following_move: "false"})

      assert refresh_record(user).allow_following_move == false
      assert user_data = json_response(conn, 200)
      assert user_data["pleroma"]["allow_following_move"] == false
    end

    test "updates the user's default scope", %{conn: conn} do
      conn = patch(conn, "/api/v1/accounts/update_credentials", %{default_scope: "cofe"})

      assert user_data = json_response(conn, 200)
      assert user_data["source"]["privacy"] == "cofe"
    end

    test "updates the user's hide_followers status", %{conn: conn} do
      conn = patch(conn, "/api/v1/accounts/update_credentials", %{hide_followers: "true"})

      assert user_data = json_response(conn, 200)
      assert user_data["pleroma"]["hide_followers"] == true
    end

    test "updates the user's hide_followers_count and hide_follows_count", %{conn: conn} do
      conn =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          hide_followers_count: "true",
          hide_follows_count: "true"
        })

      assert user_data = json_response(conn, 200)
      assert user_data["pleroma"]["hide_followers_count"] == true
      assert user_data["pleroma"]["hide_follows_count"] == true
    end

    test "updates the user's skip_thread_containment option", %{user: user, conn: conn} do
      response =
        conn
        |> patch("/api/v1/accounts/update_credentials", %{skip_thread_containment: "true"})
        |> json_response(200)

      assert response["pleroma"]["skip_thread_containment"] == true
      assert refresh_record(user).skip_thread_containment
    end

    test "updates the user's hide_follows status", %{conn: conn} do
      conn = patch(conn, "/api/v1/accounts/update_credentials", %{hide_follows: "true"})

      assert user_data = json_response(conn, 200)
      assert user_data["pleroma"]["hide_follows"] == true
    end

    test "updates the user's hide_favorites status", %{conn: conn} do
      conn = patch(conn, "/api/v1/accounts/update_credentials", %{hide_favorites: "true"})

      assert user_data = json_response(conn, 200)
      assert user_data["pleroma"]["hide_favorites"] == true
    end

    test "updates the user's show_role status", %{conn: conn} do
      conn = patch(conn, "/api/v1/accounts/update_credentials", %{show_role: "false"})

      assert user_data = json_response(conn, 200)
      assert user_data["source"]["pleroma"]["show_role"] == false
    end

    test "updates the user's no_rich_text status", %{conn: conn} do
      conn = patch(conn, "/api/v1/accounts/update_credentials", %{no_rich_text: "true"})

      assert user_data = json_response(conn, 200)
      assert user_data["source"]["pleroma"]["no_rich_text"] == true
    end

    test "updates the user's name", %{conn: conn} do
      conn =
        patch(conn, "/api/v1/accounts/update_credentials", %{"display_name" => "markorepairs"})

      assert user_data = json_response(conn, 200)
      assert user_data["display_name"] == "markorepairs"
    end

    test "updates the user's avatar", %{user: user, conn: conn} do
      new_avatar = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      conn = patch(conn, "/api/v1/accounts/update_credentials", %{"avatar" => new_avatar})

      assert user_response = json_response(conn, 200)
      assert user_response["avatar"] != User.avatar_url(user)
    end

    test "updates the user's banner", %{user: user, conn: conn} do
      new_header = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      conn = patch(conn, "/api/v1/accounts/update_credentials", %{"header" => new_header})

      assert user_response = json_response(conn, 200)
      assert user_response["header"] != User.banner_url(user)
    end

    test "updates the user's background", %{conn: conn} do
      new_header = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      conn =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          "pleroma_background_image" => new_header
        })

      assert user_response = json_response(conn, 200)
      assert user_response["pleroma"]["background_image"]
    end

    test "requires 'write:accounts' permission" do
      token1 = insert(:oauth_token, scopes: ["read"])
      token2 = insert(:oauth_token, scopes: ["write", "follow"])

      for token <- [token1, token2] do
        conn =
          build_conn()
          |> put_req_header("authorization", "Bearer #{token.token}")
          |> patch("/api/v1/accounts/update_credentials", %{})

        if token == token1 do
          assert %{"error" => "Insufficient permissions: write:accounts."} ==
                   json_response(conn, 403)
        else
          assert json_response(conn, 200)
        end
      end
    end

    test "updates profile emojos", %{user: user, conn: conn} do
      note = "*sips :blank:*"
      name = "I am :firefox:"

      ret_conn =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          "note" => note,
          "display_name" => name
        })

      assert json_response(ret_conn, 200)

      conn = get(conn, "/api/v1/accounts/#{user.id}")

      assert user_data = json_response(conn, 200)

      assert user_data["note"] == note
      assert user_data["display_name"] == name
      assert [%{"shortcode" => "blank"}, %{"shortcode" => "firefox"}] = user_data["emojis"]
    end

    test "update fields", %{conn: conn} do
      fields = [
        %{"name" => "<a href=\"http://google.com\">foo</a>", "value" => "<script>bar</script>"},
        %{"name" => "link", "value" => "cofe.io"}
      ]

      account_data =
        conn
        |> patch("/api/v1/accounts/update_credentials", %{"fields_attributes" => fields})
        |> json_response(200)

      assert account_data["fields"] == [
               %{"name" => "<a href=\"http://google.com\">foo</a>", "value" => "bar"},
               %{"name" => "link", "value" => ~S(<a href="http://cofe.io" rel="ugc">cofe.io</a>)}
             ]

      assert account_data["source"]["fields"] == [
               %{
                 "name" => "<a href=\"http://google.com\">foo</a>",
                 "value" => "<script>bar</script>"
               },
               %{"name" => "link", "value" => "cofe.io"}
             ]

      fields =
        [
          "fields_attributes[1][name]=link",
          "fields_attributes[1][value]=cofe.io",
          "fields_attributes[0][name]=<a href=\"http://google.com\">foo</a>",
          "fields_attributes[0][value]=bar"
        ]
        |> Enum.join("&")

      account =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> patch("/api/v1/accounts/update_credentials", fields)
        |> json_response(200)

      assert account["fields"] == [
               %{"name" => "<a href=\"http://google.com\">foo</a>", "value" => "bar"},
               %{"name" => "link", "value" => ~S(<a href="http://cofe.io" rel="ugc">cofe.io</a>)}
             ]

      assert account["source"]["fields"] == [
               %{
                 "name" => "<a href=\"http://google.com\">foo</a>",
                 "value" => "bar"
               },
               %{"name" => "link", "value" => "cofe.io"}
             ]

      name_limit = Pleroma.Config.get([:instance, :account_field_name_length])
      value_limit = Pleroma.Config.get([:instance, :account_field_value_length])

      long_value = Enum.map(0..value_limit, fn _ -> "x" end) |> Enum.join()

      fields = [%{"name" => "<b>foo<b>", "value" => long_value}]

      assert %{"error" => "Invalid request"} ==
               conn
               |> patch("/api/v1/accounts/update_credentials", %{"fields_attributes" => fields})
               |> json_response(403)

      long_name = Enum.map(0..name_limit, fn _ -> "x" end) |> Enum.join()

      fields = [%{"name" => long_name, "value" => "bar"}]

      assert %{"error" => "Invalid request"} ==
               conn
               |> patch("/api/v1/accounts/update_credentials", %{"fields_attributes" => fields})
               |> json_response(403)

      Pleroma.Config.put([:instance, :max_account_fields], 1)

      fields = [
        %{"name" => "<b>foo<b>", "value" => "<i>bar</i>"},
        %{"name" => "link", "value" => "cofe.io"}
      ]

      assert %{"error" => "Invalid request"} ==
               conn
               |> patch("/api/v1/accounts/update_credentials", %{"fields_attributes" => fields})
               |> json_response(403)

      fields = [
        %{"name" => "foo", "value" => ""},
        %{"name" => "", "value" => "bar"}
      ]

      account =
        conn
        |> patch("/api/v1/accounts/update_credentials", %{"fields_attributes" => fields})
        |> json_response(200)

      assert account["fields"] == [
               %{"name" => "foo", "value" => ""}
             ]
    end
  end
end
