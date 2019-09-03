defmodule Pleroma.Docs.Generator do
  @callback process(keyword()) :: {:ok, String.t()}

  @spec process(module(), keyword()) :: {:ok, String.t()}
  def process(implementation, descriptions) do
    implementation.process(descriptions)
  end

  @spec uploaders_list() :: [module()]
  def uploaders_list do
    {:ok, modules} = :application.get_key(:pleroma, :modules)

    Enum.filter(modules, fn module ->
      name_as_list = Module.split(module)

      List.starts_with?(name_as_list, ["Pleroma", "Uploaders"]) and
        List.last(name_as_list) != "Uploader"
    end)
  end

  @spec filters_list() :: [module()]
  def filters_list do
    {:ok, modules} = :application.get_key(:pleroma, :modules)

    Enum.filter(modules, fn module ->
      name_as_list = Module.split(module)

      List.starts_with?(name_as_list, ["Pleroma", "Upload", "Filter"])
    end)
  end

  @spec mrf_list() :: [module()]
  def mrf_list do
    {:ok, modules} = :application.get_key(:pleroma, :modules)

    Enum.filter(modules, fn module ->
      name_as_list = Module.split(module)

      List.starts_with?(name_as_list, ["Pleroma", "Web", "ActivityPub", "MRF"]) and
        length(name_as_list) > 4
    end)
  end

  @spec richmedia_parsers() :: [module()]
  def richmedia_parsers do
    {:ok, modules} = :application.get_key(:pleroma, :modules)

    Enum.filter(modules, fn module ->
      name_as_list = Module.split(module)

      List.starts_with?(name_as_list, ["Pleroma", "Web", "RichMedia", "Parsers"]) and
        length(name_as_list) == 5
    end)
  end
end

defimpl Jason.Encoder, for: Tuple do
  def encode(tuple, opts) do
    Jason.Encode.list(Tuple.to_list(tuple), opts)
  end
end

defimpl Jason.Encoder, for: [Regex, Function] do
  def encode(term, opts) do
    Jason.Encode.string(inspect(term), opts)
  end
end

defimpl String.Chars, for: Regex do
  def to_string(term) do
    inspect(term)
  end
end
