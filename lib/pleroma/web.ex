# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web do
  @moduledoc """
  A module that keeps using definitions for controllers,
  views and so on.

  This can be used in your application as:

      use Pleroma.Web, :controller
      use Pleroma.Web, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below.
  """

  alias Pleroma.Helpers.AuthHelper
  alias Pleroma.Web.Plugs.EnsureAuthenticatedPlug
  alias Pleroma.Web.Plugs.EnsurePublicOrAuthenticatedPlug
  alias Pleroma.Web.Plugs.ExpectAuthenticatedCheckPlug
  alias Pleroma.Web.Plugs.ExpectPublicOrAuthenticatedCheckPlug
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.Plugs.PlugHelper

  def controller do
    quote do
      use Phoenix.Controller, namespace: Pleroma.Web

      import Plug.Conn

      import Pleroma.Web.Gettext
      import Pleroma.Web.TranslationHelpers

      alias Pleroma.Web.Router.Helpers, as: Routes

      plug(:set_put_layout)

      defp set_put_layout(conn, _) do
        put_layout(conn, Pleroma.Config.get(:app_layout, "app.html"))
      end

      # Marks plugs intentionally skipped and blocks their execution if present in plugs chain
      defp skip_plug(conn, plug_modules) do
        plug_modules
        |> List.wrap()
        |> Enum.reduce(
          conn,
          fn plug_module, conn ->
            try do
              plug_module.skip_plug(conn)
            rescue
              UndefinedFunctionError ->
                raise "`#{plug_module}` is not skippable. Append `use Pleroma.Web, :plug` to its code."
            end
          end
        )
      end

      defp skip_auth(conn, _) do
        skip_plug(conn, [OAuthScopesPlug, EnsurePublicOrAuthenticatedPlug])
      end

      defp skip_public_check(conn, _) do
        skip_plug(conn, EnsurePublicOrAuthenticatedPlug)
      end

      # Executed just before actual controller action, invokes before-action hooks (callbacks)
      defp action(conn, params) do
        with %{halted: false} = conn <-
               maybe_drop_authentication_if_oauth_check_ignored(conn),
             %{halted: false} = conn <- maybe_perform_public_or_authenticated_check(conn),
             %{halted: false} = conn <- maybe_perform_authenticated_check(conn),
             %{halted: false} = conn <- maybe_halt_on_missing_oauth_scopes_check(conn) do
          super(conn, params)
        end
      end

      # For non-authenticated API actions, drops auth info if OAuth scopes check was ignored
      #   (neither performed nor explicitly skipped)
      defp maybe_drop_authentication_if_oauth_check_ignored(conn) do
        if PlugHelper.plug_called?(conn, ExpectPublicOrAuthenticatedCheckPlug) and
             not PlugHelper.plug_called_or_skipped?(conn, OAuthScopesPlug) do
          AuthHelper.drop_auth_info(conn)
        else
          conn
        end
      end

      # Ensures instance is public -or- user is authenticated if such check was scheduled
      defp maybe_perform_public_or_authenticated_check(conn) do
        if PlugHelper.plug_called?(conn, ExpectPublicOrAuthenticatedCheckPlug) do
          EnsurePublicOrAuthenticatedPlug.call(conn, %{})
        else
          conn
        end
      end

      # Ensures user is authenticated if such check was scheduled
      # Note: runs prior to action even if it was already executed earlier in plug chain
      #   (since OAuthScopesPlug has option of proceeding unauthenticated)
      defp maybe_perform_authenticated_check(conn) do
        if PlugHelper.plug_called?(conn, ExpectAuthenticatedCheckPlug) do
          EnsureAuthenticatedPlug.call(conn, %{})
        else
          conn
        end
      end

      # Halts if authenticated API action neither performs nor explicitly skips OAuth scopes check
      defp maybe_halt_on_missing_oauth_scopes_check(conn) do
        if PlugHelper.plug_called?(conn, ExpectAuthenticatedCheckPlug) and
             not PlugHelper.plug_called_or_skipped?(conn, OAuthScopesPlug) do
          conn
          |> render_error(
            :forbidden,
            "Security violation: OAuth scopes check was neither handled nor explicitly skipped."
          )
          |> halt()
        else
          conn
        end
      end
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/pleroma/web/templates",
        namespace: Pleroma.Web

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_csrf_token: 0, get_flash: 2, view_module: 1]

      import Pleroma.Web.ErrorHelpers
      import Pleroma.Web.Gettext

      alias Pleroma.Web.Router.Helpers, as: Routes

      require Logger

      @doc "Same as `render/3` but wrapped in a rescue block"
      def safe_render(view, template, assigns \\ %{}) do
        Phoenix.View.render(view, template, assigns)
      rescue
        error ->
          Logger.error(
            "#{__MODULE__} failed to render #{inspect({view, template})}\n" <>
              Exception.format(:error, error, __STACKTRACE__)
          )

          nil
      end

      @doc """
      Same as `render_many/4` but wrapped in rescue block.
      """
      def safe_render_many(collection, view, template, assigns \\ %{}) do
        Enum.map(collection, fn resource ->
          as = Map.get(assigns, :as) || view.__resource__
          assigns = Map.put(assigns, as, resource)
          safe_render(view, template, assigns)
        end)
        |> Enum.filter(& &1)
      end
    end
  end

  def router do
    quote do
      use Phoenix.Router
      # credo:disable-for-next-line Credo.Check.Consistency.MultiAliasImportRequireUse
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      # credo:disable-for-next-line Credo.Check.Consistency.MultiAliasImportRequireUse
      import Phoenix.Channel
      import Pleroma.Web.Gettext
    end
  end

  def plug do
    quote do
      @behaviour Pleroma.Web.Plug
      @behaviour Plug

      @doc """
      Marks a plug intentionally skipped and blocks its execution if it's present in plugs chain.
      """
      def skip_plug(conn) do
        PlugHelper.append_to_private_list(
          conn,
          PlugHelper.skipped_plugs_list_id(),
          __MODULE__
        )
      end

      @impl Plug
      @doc """
      Before-plug hook that
        * ensures the plug is not skipped
        * processes `:if_func` / `:unless_func` functional pre-run conditions
        * adds plug to the list of called plugs and calls `perform/2` if checks are passed

      Note: multiple invocations of the same plug (with different or same options) are allowed.
      """
      def call(%Plug.Conn{} = conn, options) do
        if PlugHelper.plug_skipped?(conn, __MODULE__) ||
             (options[:if_func] && !options[:if_func].(conn)) ||
             (options[:unless_func] && options[:unless_func].(conn)) do
          conn
        else
          conn =
            PlugHelper.append_to_private_list(
              conn,
              PlugHelper.called_plugs_list_id(),
              __MODULE__
            )

          apply(__MODULE__, :perform, [conn, options])
        end
      end
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
