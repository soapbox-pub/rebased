defmodule Pleroma.Web.XML do
  require Logger

  def string_from_xpath(xpath, :error), do: nil
  def string_from_xpath(xpath, doc) do
    {:xmlObj, :string, res} = :xmerl_xpath.string('string(#{xpath})', doc)

    res = res
    |> to_string
    |> String.trim

    if res == "", do: nil, else: res
  end

  def parse_document(text) do
    try do
      {doc, _rest} = text
      |> :binary.bin_to_list
      |> :xmerl_scan.string

      doc
    catch
      :exit, error ->
        Logger.debug("Couldn't parse xml: #{inspect(text)}")
        :error
    end
  end
end
