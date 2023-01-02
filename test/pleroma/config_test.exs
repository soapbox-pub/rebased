# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ConfigTest do
  use Pleroma.DataCase

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

  describe "nil values" do
    setup do
      clear_config(:lorem, nil)
      clear_config(:ipsum, %{dolor: [sit: nil]})
      clear_config(:dolor, sit: %{amet: nil})

      on_exit(fn -> Enum.each(~w(lorem ipsum dolor)a, &Pleroma.Config.delete/1) end)
    end

    test "get/1 with an atom for nil value" do
      assert Pleroma.Config.get(:lorem) == nil
    end

    test "get/2 with an atom for nil value" do
      assert Pleroma.Config.get(:lorem, true) == nil
    end

    test "get/1 with a list of keys for nil value" do
      assert Pleroma.Config.get([:ipsum, :dolor, :sit]) == nil
      assert Pleroma.Config.get([:dolor, :sit, :amet]) == nil
    end

    test "get/2 with a list of keys for nil value" do
      assert Pleroma.Config.get([:ipsum, :dolor, :sit], true) == nil
      assert Pleroma.Config.get([:dolor, :sit, :amet], true) == nil
    end
  end

  test "get/1 when value is false" do
    clear_config([:instance, :false_test], false)
    clear_config([:instance, :nested], [])
    clear_config([:instance, :nested, :false_test], false)

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
    clear_config([:instance, :false_test], false)
    clear_config([:instance, :nested], [])
    clear_config([:instance, :nested, :false_test], false)

    assert Pleroma.Config.get!([:instance, :false_test]) == false
    assert Pleroma.Config.get!([:instance, :nested, :false_test]) == false
  end

  test "put/2 with a key" do
    clear_config(:config_test, true)

    assert Pleroma.Config.get(:config_test) == true
  end

  test "put/2 with a list of keys" do
    clear_config([:instance, :config_test], true)
    clear_config([:instance, :config_nested_test], [])
    clear_config([:instance, :config_nested_test, :x], true)

    assert Pleroma.Config.get([:instance, :config_test]) == true
    assert Pleroma.Config.get([:instance, :config_nested_test, :x]) == true
  end

  test "delete/1 with a key" do
    clear_config([:delete_me], :delete_me)
    Pleroma.Config.delete([:delete_me])
    assert Pleroma.Config.get([:delete_me]) == nil
  end

  test "delete/2 with a list of keys" do
    clear_config([:delete_me], hello: "world", world: "Hello")
    Pleroma.Config.delete([:delete_me, :world])
    assert Pleroma.Config.get([:delete_me]) == [hello: "world"]
    clear_config([:delete_me, :delete_me], hello: "world", world: "Hello")
    Pleroma.Config.delete([:delete_me, :delete_me, :world])
    assert Pleroma.Config.get([:delete_me, :delete_me]) == [hello: "world"]

    assert Pleroma.Config.delete([:this_key_does_not_exist])
    assert Pleroma.Config.delete([:non, :existing, :key])
  end

  test "fetch/1" do
    clear_config([:lorem], :ipsum)
    clear_config([:ipsum], dolor: :sit)

    assert Pleroma.Config.fetch([:lorem]) == {:ok, :ipsum}
    assert Pleroma.Config.fetch(:lorem) == {:ok, :ipsum}
    assert Pleroma.Config.fetch([:ipsum, :dolor]) == {:ok, :sit}
    assert Pleroma.Config.fetch([:lorem, :ipsum]) == :error
    assert Pleroma.Config.fetch([:loremipsum]) == :error
    assert Pleroma.Config.fetch(:loremipsum) == :error

    Pleroma.Config.delete([:lorem])
    Pleroma.Config.delete([:ipsum])
  end
end
