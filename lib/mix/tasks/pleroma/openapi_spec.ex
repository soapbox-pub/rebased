# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.OpenapiSpec do
  def run([path]) do
    # Load Pleroma application to get version info
    Application.load(:pleroma)

    spec_json = Pleroma.Web.ApiSpec.spec(server_specific: false) |> Jason.encode!()
    # to get rid of the structs
    spec_regened = spec_json |> Jason.decode!()

    check_specs!(spec_regened)

    File.write(path, spec_json)
  end

  defp check_specs!(spec) do
    with :ok <- check_specs(spec) do
      :ok
    else
      {_, errors} ->
        IO.puts(IO.ANSI.format([:red, :bright, "Spec check failed, errors:"]))
        Enum.map(errors, &IO.puts/1)

        raise "Spec check failed"
    end
  end

  def check_specs(spec) do
    errors =
      spec["paths"]
      |> Enum.flat_map(fn {path, %{} = endpoints} ->
        Enum.map(
          endpoints,
          fn {method, endpoint} ->
            with :ok <- check_endpoint(spec, endpoint) do
              :ok
            else
              error ->
                "#{endpoint["operationId"]} (#{method} #{path}): #{error}"
            end
          end
        )
        |> Enum.reject(fn res -> res == :ok end)
      end)

    if errors == [] do
      :ok
    else
      {:error, errors}
    end
  end

  defp check_endpoint(spec, endpoint) do
    valid_tags = available_tags(spec)

    with {_, [_ | _] = tags} <- {:tags, endpoint["tags"]},
         {_, []} <- {:unavailable, Enum.reject(tags, &(&1 in valid_tags))} do
      :ok
    else
      {:tags, _} ->
        "No tags specified"

      {:unavailable, tags} ->
        "Tags #{inspect(tags)} not available. Please add it in \"x-tagGroups\" in Pleroma.Web.ApiSpec"
    end
  end

  defp available_tags(spec) do
    spec["x-tagGroups"]
    |> Enum.flat_map(fn %{"tags" => tags} -> tags end)
  end
end
