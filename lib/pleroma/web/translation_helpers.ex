# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TranslationHelpers do
  defmacro render_error(
             conn,
             status,
             msgid,
             bindings \\ Macro.escape(%{}),
             identifier \\ Macro.escape("")
           ) do
    quote do
      require Pleroma.Web.Gettext

      error_map =
        %{
          error: Pleroma.Web.Gettext.dgettext("errors", unquote(msgid), unquote(bindings)),
          identifier: unquote(identifier)
        }
        |> Enum.reject(fn {_k, v} -> v == "" end)
        |> Map.new()

      unquote(conn)
      |> Plug.Conn.put_status(unquote(status))
      |> Phoenix.Controller.json(error_map)
    end
  end
end
