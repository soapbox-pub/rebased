defmodule Pleroma.Web.TwitterAPI.Representers.BaseRepresenter do
  defmacro __using__(_opts) do
    quote do
      def to_json(object) do to_json(object, %{}) end
      def to_json(object, options) do
        object
        |> to_map(options)
        |> Jason.encode!
      end

      def enum_to_list(enum, options) do
        mapping = fn (el) -> to_map(el, options) end
        Enum.map(enum, mapping)
      end

      def to_map(object) do
        to_map(object, %{})
      end

      def enum_to_json(enum) do enum_to_json(enum, %{}) end
      def enum_to_json(enum, options) do
        enum
        |> enum_to_list(options)
        |> Jason.encode!
      end
    end
  end
end
