# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ConfigTest do
  use ExUnit.Case

  test "get/1 with an atom" do
    assert Pleroma.Config.get(:instance) == Application.get_env(:pleroma, :instance)
    assert Pleroma.Config.get(:azertyuiop) == nil
    assert Pleroma.Config.get(:azertyuiop, true) == true
  end

  test "get/1 with a list of keys" do
    assert Pleroma.Config.get([:instance, :public]) ==
             Keyword.get(Application.get_env(:pleroma, :instance), :public)

    assert Pleroma.Config.get([Pleroma.Web.Endpoint, :render_errors, :view]) ==
             get_in(
               Application.get_env(
                 :pleroma,
                 Pleroma.Web.Endpoint
               ),
               [:render_errors, :view]
             )

    assert Pleroma.Config.get([:azerty, :uiop]) == nil
    assert Pleroma.Config.get([:azerty, :uiop], true) == true
  end

  test "get/1 when value is false" do
    Pleroma.Config.put([:instance, :false_test], false)
    Pleroma.Config.put([:instance, :nested], [])
    Pleroma.Config.put([:instance, :nested, :false_test], false)

    assert Pleroma.Config.get([:instance, :false_test]) == false
    assert Pleroma.Config.get([:instance, :nested, :false_test]) == false
  end

  test "get!/1" do
    assert Pleroma.Config.get!(:instance) == Application.get_env(:pleroma, :instance)

    assert Pleroma.Config.get!([:instance, :public]) ==
             Keyword.get(Application.get_env(:pleroma, :instance), :public)

    assert_raise(Pleroma.Config.Error, fn ->
      Pleroma.Config.get!(:azertyuiop)
    end)

    assert_raise(Pleroma.Config.Error, fn ->
      Pleroma.Config.get!([:azerty, :uiop])
    end)
  end

  test "get!/1 when value is false" do
    Pleroma.Config.put([:instance, :false_test], false)
    Pleroma.Config.put([:instance, :nested], [])
    Pleroma.Config.put([:instance, :nested, :false_test], false)

    assert Pleroma.Config.get!([:instance, :false_test]) == false
    assert Pleroma.Config.get!([:instance, :nested, :false_test]) == false
  end

  test "put/2 with a key" do
    Pleroma.Config.put(:config_test, true)

    assert Pleroma.Config.get(:config_test) == true
  end

  test "put/2 with a list of keys" do
    Pleroma.Config.put([:instance, :config_test], true)
    Pleroma.Config.put([:instance, :config_nested_test], [])
    Pleroma.Config.put([:instance, :config_nested_test, :x], true)

    assert Pleroma.Config.get([:instance, :config_test]) == true
    assert Pleroma.Config.get([:instance, :config_nested_test, :x]) == true
  end

  test "delete/1 with a key" do
    Pleroma.Config.put([:delete_me], :delete_me)
    Pleroma.Config.delete([:delete_me])
    assert Pleroma.Config.get([:delete_me]) == nil
  end

  test "delete/2 with a list of keys" do
    Pleroma.Config.put([:delete_me], hello: "world", world: "Hello")
    Pleroma.Config.delete([:delete_me, :world])
    assert Pleroma.Config.get([:delete_me]) == [hello: "world"]
    Pleroma.Config.put([:delete_me, :delete_me], hello: "world", world: "Hello")
    Pleroma.Config.delete([:delete_me, :delete_me, :world])
    assert Pleroma.Config.get([:delete_me, :delete_me]) == [hello: "world"]
  end
end
