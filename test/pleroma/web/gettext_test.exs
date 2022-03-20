# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.GettextTest do
  use ExUnit.Case

  require Pleroma.Web.Gettext

  test "put_locales/1: set the first in the list to Gettext's locale" do
    Pleroma.Web.Gettext.put_locales(["zh_Hans", "en_test"])

    assert "zh_Hans" == Gettext.get_locale(Pleroma.Web.Gettext)
  end

  test "with_locales/2: reset locale on exit" do
    old_first_locale = Gettext.get_locale(Pleroma.Web.Gettext)
    old_locales = Pleroma.Web.Gettext.get_locales()

    Pleroma.Web.Gettext.with_locales ["zh_Hans", "en_test"] do
      assert "zh_Hans" == Gettext.get_locale(Pleroma.Web.Gettext)
      assert ["zh_Hans", "en_test"] == Pleroma.Web.Gettext.get_locales()
    end

    assert old_first_locale == Gettext.get_locale(Pleroma.Web.Gettext)
    assert old_locales == Pleroma.Web.Gettext.get_locales()
  end

  describe "handle_missing_translation/5" do
    test "fallback to next locale if some translation is not available" do
      Pleroma.Web.Gettext.with_locales ["x_unsupported", "en_test"] do
        assert "xxYour account is awaiting approvalxx" ==
                 Pleroma.Web.Gettext.dpgettext(
                   "static_pages",
                   "approval pending email subject",
                   "Your account is awaiting approval"
                 )
      end
    end

    test "duplicated locale in list should not result in infinite loops" do
      Pleroma.Web.Gettext.with_locales ["x_unsupported", "x_unsupported", "en_test"] do
        assert "xxYour account is awaiting approvalxx" ==
                 Pleroma.Web.Gettext.dpgettext(
                   "static_pages",
                   "approval pending email subject",
                   "Your account is awaiting approval"
                 )
      end
    end

    test "direct interpolation" do
      Pleroma.Web.Gettext.with_locales ["en_test"] do
        assert "xxYour digest from some instancexx" ==
                 Pleroma.Web.Gettext.dpgettext(
                   "static_pages",
                   "digest email subject",
                   "Your digest from %{instance_name}",
                   instance_name: "some instance"
                 )
      end
    end

    test "fallback with interpolation" do
      Pleroma.Web.Gettext.with_locales ["x_unsupported", "en_test"] do
        assert "xxYour digest from some instancexx" ==
                 Pleroma.Web.Gettext.dpgettext(
                   "static_pages",
                   "digest email subject",
                   "Your digest from %{instance_name}",
                   instance_name: "some instance"
                 )
      end
    end

    test "fallback to msgid" do
      Pleroma.Web.Gettext.with_locales ["x_unsupported"] do
        assert "Your digest from some instance" ==
                 Pleroma.Web.Gettext.dpgettext(
                   "static_pages",
                   "digest email subject",
                   "Your digest from %{instance_name}",
                   instance_name: "some instance"
                 )
      end
    end
  end

  describe "handle_missing_plural_translation/7" do
    test "direct interpolation" do
      Pleroma.Web.Gettext.with_locales ["en_test"] do
        assert "xx1 New Followerxx" ==
                 Pleroma.Web.Gettext.dpngettext(
                   "static_pages",
                   "new followers count header",
                   "%{count} New Follower",
                   "%{count} New Followers",
                   1,
                   count: 1
                 )

        assert "xx5 New Followersxx" ==
                 Pleroma.Web.Gettext.dpngettext(
                   "static_pages",
                   "new followers count header",
                   "%{count} New Follower",
                   "%{count} New Followers",
                   5,
                   count: 5
                 )
      end
    end

    test "fallback with interpolation" do
      Pleroma.Web.Gettext.with_locales ["x_unsupported", "en_test"] do
        assert "xx1 New Followerxx" ==
                 Pleroma.Web.Gettext.dpngettext(
                   "static_pages",
                   "new followers count header",
                   "%{count} New Follower",
                   "%{count} New Followers",
                   1,
                   count: 1
                 )

        assert "xx5 New Followersxx" ==
                 Pleroma.Web.Gettext.dpngettext(
                   "static_pages",
                   "new followers count header",
                   "%{count} New Follower",
                   "%{count} New Followers",
                   5,
                   count: 5
                 )
      end
    end

    test "fallback to msgid" do
      Pleroma.Web.Gettext.with_locales ["x_unsupported"] do
        assert "1 New Follower" ==
                 Pleroma.Web.Gettext.dpngettext(
                   "static_pages",
                   "new followers count header",
                   "%{count} New Follower",
                   "%{count} New Followers",
                   1,
                   count: 1
                 )

        assert "5 New Followers" ==
                 Pleroma.Web.Gettext.dpngettext(
                   "static_pages",
                   "new followers count header",
                   "%{count} New Follower",
                   "%{count} New Followers",
                   5,
                   count: 5
                 )
      end
    end
  end
end
