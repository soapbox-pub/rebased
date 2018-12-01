defmodule Pleroma.Object.ContainmentTest do
  use Pleroma.DataCase

  alias Pleroma.User
  alias Pleroma.Object.Containment
  alias Pleroma.Web.ActivityPub.ActivityPub

  import Pleroma.Factory

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
      user =
        insert(:user, %{
          nickname: "rye@niu.moe",
          local: false,
          ap_id: "https://niu.moe/users/rye",
          follower_address: User.ap_followers(%User{nickname: "rye@niu.moe"})
        })

      {:error, _} = User.get_or_fetch_by_ap_id("https://n1u.moe/users/rye")
    end

    test "all objects with fake directions are rejected by the object fetcher" do
      {:error, _} =
        ActivityPub.fetch_and_contain_remote_object_from_id(
          "https://info.pleroma.site/activity4.json"
        )
    end
  end
end
