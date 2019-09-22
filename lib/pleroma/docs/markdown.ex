defmodule Pleroma.Docs.Markdown do
  @behaviour Pleroma.Docs.Generator

  @spec process(keyword()) :: {:ok, String.t()}
  def process(descriptions) do
    config_path = "docs/generated_config.md"
    {:ok, file} = File.open(config_path, [:utf8, :write])
    IO.write(file, "# Generated configuration\n")
    IO.write(file, "Date of generation: #{Date.utc_today()}\n\n")

    IO.write(
      file,
      "This file describe the configuration, it is recommended to edit the relevant `*.secret.exs` file instead of the others founds in the ``config`` directory.\n\n" <>
        "If you run Pleroma with ``MIX_ENV=prod`` the file is ``prod.secret.exs``, otherwise it is ``dev.secret.exs``.\n\n"
    )

    for group <- descriptions do
      if is_nil(group[:key]) do
        IO.write(file, "## #{inspect(group[:group])}\n")
      else
        IO.write(file, "## #{inspect(group[:key])}\n")
      end

      IO.write(file, "#{group[:description]}\n")

      for child <- group[:children] || [] do
        print_child_header(file, child)

        print_suggestions(file, child[:suggestions])

        if child[:children] do
          for subchild <- child[:children] do
            print_child_header(file, subchild)

            print_suggestions(file, subchild[:suggestions])
          end
        end
      end

      IO.write(file, "\n")
    end

    :ok = File.close(file)
    {:ok, config_path}
  end

  defp print_child_header(file, %{key: key, type: type, description: description} = _child) do
    IO.write(
      file,
      "- `#{inspect(key)}` (`#{inspect(type)}`): #{description}  \n"
    )
  end

  defp print_child_header(file, %{key: key, type: type} = _child) do
    IO.write(file, "- `#{inspect(key)}` (`#{inspect(type)}`)  \n")
  end

  defp print_suggestion(file, suggestion) when is_list(suggestion) do
    IO.write(file, "  `#{inspect(suggestion)}`\n")
  end

  defp print_suggestion(file, suggestion) when is_function(suggestion) do
    IO.write(file, "  `#{inspect(suggestion.())}`\n")
  end

  defp print_suggestion(file, suggestion, as_list \\ false) do
    list_mark = if as_list, do: "- ", else: ""
    IO.write(file, "  #{list_mark}`#{inspect(suggestion)}`\n")
  end

  defp print_suggestions(_file, nil), do: nil

  defp print_suggestions(_file, ""), do: nil

  defp print_suggestions(file, suggestions) do
    if length(suggestions) > 1 do
      IO.write(file, "Suggestions:\n")

      for suggestion <- suggestions do
        print_suggestion(file, suggestion, true)
      end
    else
      IO.write(file, "  Suggestion: ")

      print_suggestion(file, List.first(suggestions))
    end
  end
end
