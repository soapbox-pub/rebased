# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
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

      plug(:set_put_layout)

      defp set_put_layout(conn, _) do
        put_layout(conn, Pleroma.Config.get(:app_layout, "app.html"))
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
