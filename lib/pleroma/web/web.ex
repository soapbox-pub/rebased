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
      import Pleroma.Web.Router.Helpers
      import Pleroma.Web.Gettext
    end
  end

  def view do
    quote do
      use Phoenix.View, root: "lib/pleroma/web/templates",
                        namespace: Pleroma.Web

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_csrf_token: 0, get_flash: 2, view_module: 1]

      import Pleroma.Web.Router.Helpers
      import Pleroma.Web.ErrorHelpers
      import Pleroma.Web.Gettext
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
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

  def host do
    settings = Application.get_env(:pleroma, Pleroma.Web.Endpoint)
    settings
    |> Keyword.fetch!(:url)
    |> Keyword.fetch!(:host)
  end

  def base_url do
    settings = Application.get_env(:pleroma, Pleroma.Web.Endpoint)

    host = host()

    protocol = settings |> Keyword.fetch!(:protocol)

    port_fragment = with {:ok, protocol_info} <- settings |> Keyword.fetch(String.to_atom(protocol)),
                         {:ok, port} <- protocol_info |> Keyword.fetch(:port)
    do
      ":#{port}"
    else _e ->
      ""
    end
    "#{protocol}://#{host}#{port_fragment}"
  end
end
