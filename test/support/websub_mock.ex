defmodule Pleroma.Web.WebsubMock do
  def verify(sub) do
    {:ok, sub}
  end
end
