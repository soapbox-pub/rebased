defmodule Pleroma.Web.OEmbedTest do
  use Pleroma.DataCase
  alias Pleroma.Web.OEmbed
  alias Pleroma.Web.XML
  alias Pleroma.{Object, Repo, User, Activity}
  import Pleroma.Factory
  import ExUnit.CaptureLog

  setup_all do
    :ok
  end

  test 'recognizes notices in given url' do
    url = "https://pleroma.site/notice/5"
    assert { :activity, _ } = OEmbed.recognize_path(url)
  end

  test 'recognizes user card in given url' do
    url = "https://pleroma.site/users/raeno"
    assert { :user, _ } = OEmbed.recognize_path(url)
  end

end
