defmodule Pleroma.Docs.Generator do
  @callback process(keyword()) :: {:ok, String.t()}

  @spec process(module(), keyword()) :: {:ok, String.t()}
  def process(implementation, descriptions) do
    implementation.process(descriptions)
  end

  @spec list_modules_in_dir(String.t(), String.t()) :: [module()]
  def list_modules_in_dir(dir, start) do
    with {:ok, files} <- File.ls(dir) do
      files
      |> Enum.filter(&String.ends_with?(&1, ".ex"))
      |> Enum.map(fn filename ->
        module = filename |> String.trim_trailing(".ex") |> Macro.camelize()
        String.to_atom(start <> module)
      end)
    end
  end

  @doc """
  Converts:
  - atoms to strings with leading `:`
  - module names to strings, without leading `Elixir.`
  - add humanized labels to `keys` if label is not defined, e.g. `:instance` -> `Instance`
  """
  @spec convert_to_strings([map()]) :: [map()]
  def convert_to_strings(descriptions) do
    Enum.map(descriptions, &format_entity(&1))
  end

  defp format_entity(entity) do
    entity
    |> format_key()
    |> Map.put(:group, atom_to_string(entity[:group]))
    |> format_children()
  end

  defp format_key(%{key: key} = entity) do
    entity
    |> Map.put(:key, atom_to_string(key))
    |> Map.put(:label, entity[:label] || humanize(key))
  end

  defp format_key(%{group: group} = entity) do
    Map.put(entity, :label, entity[:label] || humanize(group))
  end

  defp format_key(entity), do: entity

  defp format_children(%{children: children} = entity) do
    Map.put(entity, :children, Enum.map(children, &format_child(&1)))
  end

  defp format_children(entity), do: entity

  defp format_child(%{suggestions: suggestions} = entity) do
    entity
    |> Map.put(:suggestions, format_suggestions(suggestions))
    |> format_key()
    |> format_group()
    |> format_children()
  end

  defp format_child(entity) do
    entity
    |> format_key()
    |> format_group()
    |> format_children()
  end

  defp format_group(%{group: group} = entity) do
    Map.put(entity, :group, format_suggestion(group))
  end

  defp format_group(entity), do: entity

  defp atom_to_string(entity) when is_binary(entity), do: entity

  defp atom_to_string(entity) when is_atom(entity), do: inspect(entity)

  defp humanize(entity) do
    string = inspect(entity)

    if String.starts_with?(string, ":"),
      do: Phoenix.Naming.humanize(entity),
      else: string
  end

  defp format_suggestions([]), do: []

  defp format_suggestions([suggestion | tail]) do
    [format_suggestion(suggestion) | format_suggestions(tail)]
  end

  defp format_suggestion(entity) when is_atom(entity) do
    atom_to_string(entity)
  end

  defp format_suggestion([head | tail] = entity) when is_list(entity) do
    [format_suggestion(head) | format_suggestions(tail)]
  end

  defp format_suggestion(entity) when is_tuple(entity) do
    format_suggestions(Tuple.to_list(entity)) |> List.to_tuple()
  end

  defp format_suggestion(entity), do: entity
end

defimpl Jason.Encoder, for: Tuple do
  def encode(tuple, opts), do: Jason.Encode.list(Tuple.to_list(tuple), opts)
end

defimpl Jason.Encoder, for: [Regex, Function] do
  def encode(term, opts), do: Jason.Encode.string(inspect(term), opts)
end

defimpl String.Chars, for: Regex do
  def to_string(term), do: inspect(term)
end
