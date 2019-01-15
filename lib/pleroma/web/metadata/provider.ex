defmodule Pleroma.Web.Metadata.Providers.Provider do
  @callback build_tags(map()) :: list()
end
