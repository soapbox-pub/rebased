# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Instances.InstanceTest do
  alias Pleroma.Instances
  alias Pleroma.Instances.Instance
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.Web.CommonAPI

  use Pleroma.DataCase

  import ExUnit.CaptureLog
  import Pleroma.Factory

  setup_all do: clear_config([:instance, :federation_reachability_timeout_days], 1)

  describe "set_reachable/1" do
    test "clears `unreachable_since` of existing matching Instance record having non-nil `unreachable_since`" do
      unreachable_since = NaiveDateTime.to_iso8601(NaiveDateTime.utc_now())
      instance = insert(:instance, unreachable_since: unreachable_since)

      assert {:ok, instance} = Instance.set_reachable(instance.host)
      refute instance.unreachable_since
    end

    test "keeps nil `unreachable_since` of existing matching Instance record having nil `unreachable_since`" do
      instance = insert(:instance, unreachable_since: nil)

      assert {:ok, instance} = Instance.set_reachable(instance.host)
      refute instance.unreachable_since
    end

    test "does NOT create an Instance record in case of no existing matching record" do
      host = "domain.org"
      assert nil == Instance.set_reachable(host)

      assert [] = Repo.all(Ecto.Query.from(i in Instance))
      assert Instance.reachable?(host)
    end
  end

  describe "set_unreachable/1" do
    test "creates new record having `unreachable_since` to current time if record does not exist" do
      assert {:ok, instance} = Instance.set_unreachable("https://domain.com/path")

      instance = Repo.get(Instance, instance.id)
      assert instance.unreachable_since
      assert "domain.com" == instance.host
    end

    test "sets `unreachable_since` of existing record having nil `unreachable_since`" do
      instance = insert(:instance, unreachable_since: nil)
      refute instance.unreachable_since

      assert {:ok, _} = Instance.set_unreachable(instance.host)

      instance = Repo.get(Instance, instance.id)
      assert instance.unreachable_since
    end

    test "does NOT modify `unreachable_since` value of existing record in case it's present" do
      instance =
        insert(:instance, unreachable_since: NaiveDateTime.add(NaiveDateTime.utc_now(), -10))

      assert instance.unreachable_since
      initial_value = instance.unreachable_since

      assert {:ok, _} = Instance.set_unreachable(instance.host)

      instance = Repo.get(Instance, instance.id)
      assert initial_value == instance.unreachable_since
    end
  end

  describe "set_unreachable/2" do
    test "sets `unreachable_since` value of existing record in case it's newer than supplied value" do
      instance =
        insert(:instance, unreachable_since: NaiveDateTime.add(NaiveDateTime.utc_now(), -10))

      assert instance.unreachable_since

      past_value = NaiveDateTime.add(NaiveDateTime.utc_now(), -100)
      assert {:ok, _} = Instance.set_unreachable(instance.host, past_value)

      instance = Repo.get(Instance, instance.id)
      assert past_value == instance.unreachable_since
    end

    test "does NOT modify `unreachable_since` value of existing record in case it's equal to or older than supplied value" do
      instance =
        insert(:instance, unreachable_since: NaiveDateTime.add(NaiveDateTime.utc_now(), -10))

      assert instance.unreachable_since
      initial_value = instance.unreachable_since

      assert {:ok, _} = Instance.set_unreachable(instance.host, NaiveDateTime.utc_now())

      instance = Repo.get(Instance, instance.id)
      assert initial_value == instance.unreachable_since
    end
  end

  describe "get_or_update_favicon/1" do
    test "Scrapes favicon URLs" do
      Tesla.Mock.mock(fn %{url: "https://favicon.example.org/"} ->
        %Tesla.Env{
          status: 200,
          body: ~s[<html><head><link rel="icon" href="/favicon.png"></head></html>]
        }
      end)

      assert "https://favicon.example.org/favicon.png" ==
               Instance.get_or_update_favicon(URI.parse("https://favicon.example.org/"))
    end

    test "Returns nil on too long favicon URLs" do
      long_favicon_url =
        "https://Lorem.ipsum.dolor.sit.amet/consecteturadipiscingelit/Praesentpharetrapurusutaliquamtempus/Mauriseulaoreetarcu/atfacilisisorci/Nullamporttitor/nequesedfeugiatmollis/dolormagnaefficiturlorem/nonpretiumsapienorcieurisus/Nullamveleratsem/Maecenassedaccumsanexnam/favicon.png"

      Tesla.Mock.mock(fn %{url: "https://long-favicon.example.org/"} ->
        %Tesla.Env{
          status: 200,
          body:
            ~s[<html><head><link rel="icon" href="] <> long_favicon_url <> ~s["></head></html>]
        }
      end)

      assert capture_log(fn ->
               assert nil ==
                        Instance.get_or_update_favicon(
                          URI.parse("https://long-favicon.example.org/")
                        )
             end) =~
               "Instance.get_or_update_favicon(\"long-favicon.example.org\") error: %Postgrex.Error{"
    end

    test "Handles not getting a favicon URL properly" do
      Tesla.Mock.mock(fn %{url: "https://no-favicon.example.org/"} ->
        %Tesla.Env{
          status: 200,
          body: ~s[<html><head><h1>I wil look down and whisper "GNO.."</h1></head></html>]
        }
      end)

      refute capture_log(fn ->
               assert nil ==
                        Instance.get_or_update_favicon(
                          URI.parse("https://no-favicon.example.org/")
                        )
             end) =~ "Instance.scrape_favicon(\"https://no-favicon.example.org/\") error: "
    end

    test "Doesn't scrapes unreachable instances" do
      instance = insert(:instance, unreachable_since: Instances.reachability_datetime_threshold())
      url = "https://" <> instance.host

      assert capture_log(fn -> assert nil == Instance.get_or_update_favicon(URI.parse(url)) end) =~
               "Instance.scrape_favicon(\"#{url}\") ignored unreachable host"
    end
  end

  test "delete_users_and_activities/1 deletes remote instance users and activities" do
    [mario, luigi, _peach, wario] =
      users = [
        insert(:user, nickname: "mario@mushroom.kingdom", name: "Mario"),
        insert(:user, nickname: "luigi@mushroom.kingdom", name: "Luigi"),
        insert(:user, nickname: "peach@mushroom.kingdom", name: "Peach"),
        insert(:user, nickname: "wario@greedville.biz", name: "Wario")
      ]

    {:ok, post1} = CommonAPI.post(mario, %{status: "letsa go!"})
    {:ok, post2} = CommonAPI.post(luigi, %{status: "itsa me... luigi"})
    {:ok, post3} = CommonAPI.post(wario, %{status: "WHA-HA-HA!"})

    {:ok, job} = Instance.delete_users_and_activities("mushroom.kingdom")
    :ok = ObanHelpers.perform(job)

    [mario, luigi, peach, wario] = Repo.reload(users)

    refute mario.is_active
    refute luigi.is_active
    refute peach.is_active
    refute peach.name == "Peach"

    assert wario.is_active
    assert wario.name == "Wario"

    assert [nil, nil, %{}] = Repo.reload([post1, post2, post3])
  end
end
