defmodule Pleroma.ObjectTombstone do
  @enforce_keys [:id, :formerType, :deleted]
  defstruct [:id, :formerType, :deleted, type: "Tombstone"]
end
