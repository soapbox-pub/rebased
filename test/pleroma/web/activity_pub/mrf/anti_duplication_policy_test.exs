defmodule Pleroma.Web.ActivityPub.MRF.AntiDuplicationPolicyTest do
  use Pleroma.DataCase
  alias Pleroma.Web.ActivityPub.MRF.AntiDuplicationPolicy

  test "prevents the same message twice" do
    message = %{
      "type" => "Create",
      "object" => %{
        "type" => "Note",
        "content" =>
          "In the beginning God created the heaven and the earth. And the earth was without form, and void; and darkness was upon the face of the deep."
      }
    }

    {:ok, _} = AntiDuplicationPolicy.filter(message)
    {:reject, _} = AntiDuplicationPolicy.filter(message)
  end

  test "allows short messages to be duplicated" do
    message = %{
      "type" => "Create",
      "object" => %{
        "type" => "Note",
        "content" => "hello world"
      }
    }

    {:ok, _} = AntiDuplicationPolicy.filter(message)
    {:ok, _} = AntiDuplicationPolicy.filter(message)
  end
end
