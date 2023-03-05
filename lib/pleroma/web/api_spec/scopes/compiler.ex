# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Scopes.Compiler do
  defmacro __before_compile__(_env) do
    strings = __MODULE__.extract_all_scopes()

    quote do
      def placeholder do
        unquote do
          Enum.map(
            strings,
            fn string ->
              quote do
                Pleroma.Web.Gettext.dgettext_noop(
                  "oauth_scopes",
                  unquote(string)
                )
              end
            end
          )
        end
      end
    end
  end

  def extract_all_scopes do
    extract_all_scopes_from(Pleroma.Web.ApiSpec.spec())
  end

  def extract_all_scopes_from(specs) do
    specs.paths
    |> Enum.reduce([], fn
      {_path, %{} = path_item}, acc ->
        extract_routes(path_item)
        |> Enum.flat_map(fn operation -> process_operation(operation) end)
        |> Kernel.++(acc)

      {_, _}, acc ->
        acc
    end)
    |> Enum.uniq()
  end

  defp extract_routes(path_item) do
    path_item
    |> Map.from_struct()
    |> Enum.map(fn {_method, path_item} -> path_item end)
    |> Enum.filter(fn
      %OpenApiSpex.Operation{} = _operation -> true
      _ -> false
    end)
  end

  defp process_operation(operation) do
    operation.security
    |> Kernel.||([])
    |> Enum.flat_map(fn
      %{"oAuth" => scopes} -> process_scopes(scopes)
      _ -> []
    end)
  end

  defp process_scopes(scopes) do
    scopes
    |> Enum.flat_map(fn scope ->
      process_scope(scope)
    end)
  end

  def process_scope(scope) do
    hierarchy = String.split(scope, ":")

    {_, list} =
      Enum.reduce(hierarchy, {"", []}, fn comp, {cur, list} ->
        {cur <> comp <> ":", [cur <> comp | list]}
      end)

    list
  end
end
