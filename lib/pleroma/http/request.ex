# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.Request do
  @moduledoc """
  Request struct.
  """
  defstruct method: :get, url: "", query: [], headers: [], body: "", opts: []

  @type method :: :head | :get | :delete | :trace | :options | :post | :put | :patch
  @type url :: String.t()
  @type headers :: [{String.t(), String.t()}]

  @type t :: %__MODULE__{
          method: method(),
          url: url(),
          query: keyword(),
          headers: headers(),
          body: String.t(),
          opts: keyword()
        }
end
