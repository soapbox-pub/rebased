# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
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

  def controller do
    quote do
      use Phoenix.Controller, namespace: Pleroma.Web

      import Plug.Conn
      import Pleroma.Web.Gettext
      import Pleroma.Web.Router.Helpers
      import Pleroma.Web.TranslationHelpers

      alias Pleroma.Plugs.PlugHelper

      plug(:set_put_layout)

      defp set_put_layout(conn, _) do
        put_layout(conn, Pleroma.Config.get(:app_layout, "app.html"))
      end

      # Marks a plug intentionally skipped and blocks its execution if it's present in plugs chain
      defp skip_plug(conn, plug_module) do
        try do
          plug_module.ensure_skippable()
        rescue
          UndefinedFunctionError ->
            raise "#{plug_module} is not skippable. Append `use Pleroma.Web, :plug` to its code."
        end

        PlugHelper.append_to_skipped_plugs(conn, plug_module)
      end

      # Here we can apply before-action hooks (e.g. verify whether auth checks were preformed)
      defp action(conn, params) do
        if Pleroma.Plugs.AuthExpectedPlug.auth_expected?(conn) &&
             not PlugHelper.plug_called_or_skipped?(conn, Pleroma.Plugs.OAuthScopesPlug) do
          conn
          |> render_error(
            :forbidden,
            "Security violation: OAuth scopes check was neither handled nor explicitly skipped."
          )
          |> halt()
        else
          super(conn, params)
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
      import Pleroma.Web.Router.Helpers

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
      use Phoenix.Channel
      import Pleroma.Web.Gettext
    end
  end

  def plug do
    quote do
      alias Pleroma.Plugs.PlugHelper

      def ensure_skippable, do: :noop

      @impl Plug
      @doc "If marked as skipped, returns `conn`, and calls `perform/2` otherwise."
      def call(%Plug.Conn{} = conn, options) do
        if PlugHelper.plug_skipped?(conn, __MODULE__) do
          conn
        else
          conn
          |> PlugHelper.append_to_called_plugs(__MODULE__)
          |> perform(options)
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

  def base_url do
    Pleroma.Web.Endpoint.url()
  end
end
