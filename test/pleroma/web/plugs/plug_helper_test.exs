# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.PlugHelperTest do
  @moduledoc "Tests for the functionality added via `use Pleroma.Web, :plug`"

  alias Pleroma.Web.Plugs.ExpectAuthenticatedCheckPlug
  alias Pleroma.Web.Plugs.ExpectPublicOrAuthenticatedCheckPlug
  alias Pleroma.Web.Plugs.PlugHelper

  import Mock

  use Pleroma.Web.ConnCase

  describe "when plug is skipped, " do
    setup_with_mocks(
      [
        {ExpectPublicOrAuthenticatedCheckPlug, [:passthrough], []}
      ],
      %{conn: conn}
    ) do
      conn = ExpectPublicOrAuthenticatedCheckPlug.skip_plug(conn)
      %{conn: conn}
    end

    test "it neither adds plug to called plugs list nor calls `perform/2`, " <>
           "regardless of :if_func / :unless_func options",
         %{conn: conn} do
      for opts <- [%{}, %{if_func: fn _ -> true end}, %{unless_func: fn _ -> false end}] do
        ret_conn = ExpectPublicOrAuthenticatedCheckPlug.call(conn, opts)

        refute called(ExpectPublicOrAuthenticatedCheckPlug.perform(:_, :_))
        refute PlugHelper.plug_called?(ret_conn, ExpectPublicOrAuthenticatedCheckPlug)
      end
    end
  end

  describe "when plug is NOT skipped, " do
    setup_with_mocks([{ExpectAuthenticatedCheckPlug, [:passthrough], []}]) do
      :ok
    end

    test "with no pre-run checks, adds plug to called plugs list and calls `perform/2`", %{
      conn: conn
    } do
      ret_conn = ExpectAuthenticatedCheckPlug.call(conn, %{})

      assert called(ExpectAuthenticatedCheckPlug.perform(ret_conn, :_))
      assert PlugHelper.plug_called?(ret_conn, ExpectAuthenticatedCheckPlug)
    end

    test "when :if_func option is given, calls the plug only if provided function evals tru-ish",
         %{conn: conn} do
      ret_conn = ExpectAuthenticatedCheckPlug.call(conn, %{if_func: fn _ -> false end})

      refute called(ExpectAuthenticatedCheckPlug.perform(:_, :_))
      refute PlugHelper.plug_called?(ret_conn, ExpectAuthenticatedCheckPlug)

      ret_conn = ExpectAuthenticatedCheckPlug.call(conn, %{if_func: fn _ -> true end})

      assert called(ExpectAuthenticatedCheckPlug.perform(ret_conn, :_))
      assert PlugHelper.plug_called?(ret_conn, ExpectAuthenticatedCheckPlug)
    end

    test "if :unless_func option is given, calls the plug only if provided function evals falsy",
         %{conn: conn} do
      ret_conn = ExpectAuthenticatedCheckPlug.call(conn, %{unless_func: fn _ -> true end})

      refute called(ExpectAuthenticatedCheckPlug.perform(:_, :_))
      refute PlugHelper.plug_called?(ret_conn, ExpectAuthenticatedCheckPlug)

      ret_conn = ExpectAuthenticatedCheckPlug.call(conn, %{unless_func: fn _ -> false end})

      assert called(ExpectAuthenticatedCheckPlug.perform(ret_conn, :_))
      assert PlugHelper.plug_called?(ret_conn, ExpectAuthenticatedCheckPlug)
    end

    test "allows a plug to be called multiple times (even if it's in called plugs list)", %{
      conn: conn
    } do
      conn = ExpectAuthenticatedCheckPlug.call(conn, %{an_option: :value1})
      assert called(ExpectAuthenticatedCheckPlug.perform(conn, %{an_option: :value1}))

      assert PlugHelper.plug_called?(conn, ExpectAuthenticatedCheckPlug)

      conn = ExpectAuthenticatedCheckPlug.call(conn, %{an_option: :value2})
      assert called(ExpectAuthenticatedCheckPlug.perform(conn, %{an_option: :value2}))
    end
  end
end
