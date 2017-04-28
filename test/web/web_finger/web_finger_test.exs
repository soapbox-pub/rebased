defmodule Pleroma.Web.WebFingerTest do
  use Pleroma.DataCase

  describe "host meta" do
    test "returns a link to the xml lrdd" do
      host_info = Pleroma.Web.WebFinger.host_meta

      assert String.contains?(host_info, Pleroma.Web.base_url)
    end
  end
end
