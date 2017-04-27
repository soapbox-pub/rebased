defmodule Pleroma.Web.XML do
  def string_from_xpath(xpath, doc) do
    {:xmlObj, :string, res} = :xmerl_xpath.string('string(#{xpath})', doc)

    res = res
    |> to_string
    |> String.trim

    if res == "", do: nil, else: res
  end

  def parse_document(text) do
    {doc, _rest} = text
    |> :binary.bin_to_list
    |> :xmerl_scan.string

    doc
  end
end
