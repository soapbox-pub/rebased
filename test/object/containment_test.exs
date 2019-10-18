# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Object.ContainmentTest do
  use Pleroma.DataCase

  alias Pleroma.Object.Containment
  alias Pleroma.User

  import Pleroma.Factory
  import ExUnit.CaptureLog

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "general origin containment" do
    test "contain_origin_from_id() catches obvious spoofing attempts" do
      data = %{
        "id" => "http://example.com/~alyssa/activities/1234.json"
      }

      :error =
        Containment.contain_origin_from_id(
          "http://example.org/~alyssa/activities/1234.json",
          data
        )
    end

    test "contain_origin_from_id() allows alternate IDs within the same origin domain" do
      data = %{
        "id" => "http://example.com/~alyssa/activities/1234.json"
      }

      :ok =
        Containment.contain_origin_from_id(
          "http://example.com/~alyssa/activities/1234",
          data
        )
    end

    test "contain_origin_from_id() allows matching IDs" do
      data = %{
        "id" => "http://example.com/~alyssa/activities/1234.json"
      }

      :ok =
        Containment.contain_origin_from_id(
          "http://example.com/~alyssa/activities/1234.json",
          data
        )
    end

    test "users cannot be collided through fake direction spoofing attempts" do
      _user =
        insert(:user, %{
          nickname: "rye@niu.moe",
          local: false,
          ap_id: "https://niu.moe/users/rye",
          follower_address: User.ap_followers(%User{nickname: "rye@niu.moe"})
        })

      assert capture_log(fn ->
               {:error, _} = User.get_or_fetch_by_ap_id("https://n1u.moe/users/rye")
             end) =~
               "[error] Could not decode user at fetch https://n1u.moe/users/rye"
    end
  end

  describe "containment of children" do
    test "contain_child() catches spoofing attempts" do
      data = %{
        "id" => "http://example.com/whatever",
        "type" => "Create",
        "object" => %{
          "id" => "http://example.net/~alyssa/activities/1234",
          "attributedTo" => "http://example.org/~alyssa"
        },
        "actor" => "http://example.com/~bob"
      }

      :error = Containment.contain_child(data)
    end

    test "contain_child() allows correct origins" do
      data = %{
        "id" => "http://example.org/~alyssa/activities/5678",
        "type" => "Create",
        "object" => %{
          "id" => "http://example.org/~alyssa/activities/1234",
          "attributedTo" => "http://example.org/~alyssa"
        },
        "actor" => "http://example.org/~alyssa"
      }

      :ok = Containment.contain_child(data)
    end
  end
end
