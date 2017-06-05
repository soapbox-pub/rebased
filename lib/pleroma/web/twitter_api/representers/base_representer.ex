defmodule Pleroma.Web.TwitterAPI.Representers.BaseRepresenter do
  defmacro __using__(_opts) do
    quote do
      alias Calendar.Strftime
      def to_json(object) do to_json(object, %{}) end
      def to_json(object, options) do
        object
        |> to_map(options)
        |> Poison.encode!
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
        |> Poison.encode!
      end

      def format_asctime(date) do
        Strftime.strftime!(date, "%a %b %d %H:%M:%S %z %Y")
      end

      def date_to_asctime(date) do
        with {:ok, date, _offset} <- date |> DateTime.from_iso8601 do
            format_asctime(date)
        else _e ->
            ""
        end
      end
    end
  end
end
