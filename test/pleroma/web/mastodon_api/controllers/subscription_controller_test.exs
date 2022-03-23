# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SubscriptionControllerTest do
  use Pleroma.Web.ConnCase, async: true

  import Pleroma.Factory

  alias Pleroma.Web.Push
  alias Pleroma.Web.Push.Subscription

  @sub %{
    "endpoint" => "https://example.com/example/1234",
    "keys" => %{
      "auth" => "8eDyX_uCN0XRhSbY5hs7Hg==",
      "p256dh" =>
        "BCIWgsnyXDv1VkhqL2P7YRBvdeuDnlwAPT2guNhdIoW3IP7GmHh1SMKPLxRf7x8vJy6ZFK3ol2ohgn_-0yP7QQA="
    }
  }
  @server_key Keyword.get(Push.vapid_config(), :public_key)

  setup do
    user = insert(:user)
    token = insert(:oauth_token, user: user, scopes: ["push"])

    conn =
      build_conn()
      |> assign(:user, user)
      |> assign(:token, token)
      |> put_req_header("content-type", "application/json")

    %{conn: conn, user: user, token: token}
  end

  defmacro assert_error_when_disable_push(do: yield) do
    quote do
      vapid_details = Application.get_env(:web_push_encryption, :vapid_details, [])
      Application.put_env(:web_push_encryption, :vapid_details, [])

      assert %{"error" => "Web push subscription is disabled on this Pleroma instance"} ==
               unquote(yield)

      Application.put_env(:web_push_encryption, :vapid_details, vapid_details)
    end
  end

  describe "when disabled" do
    test "POST returns error", %{conn: conn} do
      assert_error_when_disable_push do
        conn
        |> post("/api/v1/push/subscription", %{
          "data" => %{"alerts" => %{"mention" => true}},
          "subscription" => @sub
        })
        |> json_response_and_validate_schema(403)
      end
    end

    test "GET returns error", %{conn: conn} do
      assert_error_when_disable_push do
        conn
        |> get("/api/v1/push/subscription", %{})
        |> json_response_and_validate_schema(403)
      end
    end

    test "PUT returns error", %{conn: conn} do
      assert_error_when_disable_push do
        conn
        |> put("/api/v1/push/subscription", %{data: %{"alerts" => %{"mention" => false}}})
        |> json_response_and_validate_schema(403)
      end
    end

    test "DELETE returns error", %{conn: conn} do
      assert_error_when_disable_push do
        conn
        |> delete("/api/v1/push/subscription", %{})
        |> json_response_and_validate_schema(403)
      end
    end
  end

  describe "creates push subscription" do
    test "ignores unsupported types", %{conn: conn} do
      result =
        conn
        |> post("/api/v1/push/subscription", %{
          "data" => %{
            "alerts" => %{
              "fake_unsupported_type" => true
            }
          },
          "subscription" => @sub
        })
        |> json_response_and_validate_schema(200)

      refute %{
               "alerts" => %{
                 "fake_unsupported_type" => true
               }
             } == result
    end

    test "successful creation", %{conn: conn} do
      result =
        conn
        |> post("/api/v1/push/subscription", %{
          "data" => %{
            "alerts" => %{
              "mention" => true,
              "favourite" => true,
              "follow" => true,
              "reblog" => true,
              "pleroma:chat_mention" => true,
              "pleroma:emoji_reaction" => true
            }
          },
          "subscription" => @sub
        })
        |> json_response_and_validate_schema(200)

      [subscription] = Pleroma.Repo.all(Subscription)

      assert %{
               "alerts" => %{
                 "mention" => true,
                 "favourite" => true,
                 "follow" => true,
                 "reblog" => true,
                 "pleroma:chat_mention" => true,
                 "pleroma:emoji_reaction" => true
               },
               "endpoint" => subscription.endpoint,
               "id" => to_string(subscription.id),
               "server_key" => @server_key
             } == result
    end
  end

  describe "gets a user subscription" do
    test "returns error when user hasn't subscription", %{conn: conn} do
      res =
        conn
        |> get("/api/v1/push/subscription", %{})
        |> json_response_and_validate_schema(404)

      assert %{"error" => "Record not found"} == res
    end

    test "returns a user subsciption", %{conn: conn, user: user, token: token} do
      subscription =
        insert(:push_subscription,
          user: user,
          token: token,
          data: %{"alerts" => %{"mention" => true}}
        )

      res =
        conn
        |> get("/api/v1/push/subscription", %{})
        |> json_response_and_validate_schema(200)

      expect = %{
        "alerts" => %{"mention" => true},
        "endpoint" => "https://example.com/example/1234",
        "id" => to_string(subscription.id),
        "server_key" => @server_key
      }

      assert expect == res
    end
  end

  describe "updates a user subsciption" do
    setup %{conn: conn, user: user, token: token} do
      subscription =
        insert(:push_subscription,
          user: user,
          token: token,
          data: %{
            "alerts" => %{
              "mention" => true,
              "favourite" => true,
              "follow" => true,
              "reblog" => true,
              "pleroma:chat_mention" => true,
              "pleroma:emoji_reaction" => true
            }
          }
        )

      %{conn: conn, user: user, token: token, subscription: subscription}
    end

    test "returns updated subsciption", %{conn: conn, subscription: subscription} do
      res =
        conn
        |> put("/api/v1/push/subscription", %{
          data: %{
            "alerts" => %{
              "mention" => false,
              "favourite" => false,
              "follow" => false,
              "reblog" => false,
              "pleroma:chat_mention" => false,
              "pleroma:emoji_reaction" => false
            }
          }
        })
        |> json_response_and_validate_schema(200)

      expect = %{
        "alerts" => %{
          "mention" => false,
          "favourite" => false,
          "follow" => false,
          "reblog" => false,
          "pleroma:chat_mention" => false,
          "pleroma:emoji_reaction" => false
        },
        "endpoint" => "https://example.com/example/1234",
        "id" => to_string(subscription.id),
        "server_key" => @server_key
      }

      assert expect == res
    end
  end

  describe "deletes the user subscription" do
    test "returns error when user hasn't subscription", %{conn: conn} do
      res =
        conn
        |> delete("/api/v1/push/subscription", %{})
        |> json_response_and_validate_schema(404)

      assert %{"error" => "Record not found"} == res
    end

    test "returns empty result and delete user subsciption", %{
      conn: conn,
      user: user,
      token: token
    } do
      subscription =
        insert(:push_subscription,
          user: user,
          token: token,
          data: %{"alerts" => %{"mention" => true}}
        )

      res =
        conn
        |> delete("/api/v1/push/subscription", %{})
        |> json_response_and_validate_schema(200)

      assert %{} == res
      refute Pleroma.Repo.get(Subscription, subscription.id)
    end
  end
end
