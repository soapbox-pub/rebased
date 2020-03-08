# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule HttpRequestMock do
  require Logger

  def request(
        %Tesla.Env{
          url: url,
          method: method,
          headers: headers,
          query: query,
          body: body
        } = _env
      ) do
    with {:ok, res} <- apply(__MODULE__, method, [url, query, body, headers]) do
      res
    else
      error ->
        with {:error, message} <- error do
          Logger.warn(to_string(message))
        end

        {_, _r} = error
    end
  end

  # GET Requests
  #
  def get(url, query \\ [], body \\ [], headers \\ [])

  def get("https://osada.macgirvin.com/channel/mike", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___osada.macgirvin.com_channel_mike.json")
     }}
  end

  def get("https://shitposter.club/users/moonman", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/moonman@shitposter.club.json")
     }}
  end

  def get("https://mastodon.social/users/emelie/statuses/101849165031453009", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/status.emelie.json")
     }}
  end

  def get("https://mastodon.social/users/emelie/statuses/101849165031453404", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 404,
       body: ""
     }}
  end

  def get("https://mastodon.social/users/emelie", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/emelie.json")
     }}
  end

  def get("https://mastodon.social/users/not_found", _, _, _) do
    {:ok, %Tesla.Env{status: 404}}
  end

  def get("https://mastodon.sdf.org/users/rinpatch", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/rinpatch.json")
     }}
  end

  def get(
        "https://mastodon.social/.well-known/webfinger?resource=https://mastodon.social/users/emelie",
        _,
        _,
        _
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/webfinger_emelie.json")
     }}
  end

  def get("https://mastodon.social/users/emelie.atom", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/emelie.atom")
     }}
  end

  def get(
        "https://osada.macgirvin.com/.well-known/webfinger?resource=acct:mike@osada.macgirvin.com",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mike@osada.macgirvin.com.json")
     }}
  end

  def get(
        "https://social.heldscal.la/.well-known/webfinger?resource=https://social.heldscal.la/user/29191",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___social.heldscal.la_user_29191.xml")
     }}
  end

  def get("https://pawoo.net/users/pekorino.atom", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___pawoo.net_users_pekorino.atom")
     }}
  end

  def get(
        "https://pawoo.net/.well-known/webfinger?resource=acct:https://pawoo.net/users/pekorino",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___pawoo.net_users_pekorino.xml")
     }}
  end

  def get(
        "https://social.stopwatchingus-heidelberg.de/api/statuses/user_timeline/18330.atom",
        _,
        _,
        _
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/atarifrosch_feed.xml")
     }}
  end

  def get(
        "https://social.stopwatchingus-heidelberg.de/.well-known/webfinger?resource=acct:https://social.stopwatchingus-heidelberg.de/user/18330",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/atarifrosch_webfinger.xml")
     }}
  end

  def get("https://mamot.fr/users/Skruyb.atom", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___mamot.fr_users_Skruyb.atom")
     }}
  end

  def get(
        "https://mamot.fr/.well-known/webfinger?resource=acct:https://mamot.fr/users/Skruyb",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/skruyb@mamot.fr.atom")
     }}
  end

  def get(
        "https://social.heldscal.la/.well-known/webfinger?resource=nonexistant@social.heldscal.la",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/nonexistant@social.heldscal.la.xml")
     }}
  end

  def get(
        "https://squeet.me/xrd/?uri=lain@squeet.me",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/lain_squeet.me_webfinger.xml")
     }}
  end

  def get(
        "https://mst3k.interlinked.me/users/luciferMysticus",
        _,
        _,
        Accept: "application/activity+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/lucifermysticus.json")
     }}
  end

  def get("https://prismo.news/@mxb", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___prismo.news__mxb.json")
     }}
  end

  def get(
        "https://hubzilla.example.org/channel/kaniini",
        _,
        _,
        Accept: "application/activity+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/kaniini@hubzilla.example.org.json")
     }}
  end

  def get("https://niu.moe/users/rye", _, _, Accept: "application/activity+json") do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/rye.json")
     }}
  end

  def get("https://n1u.moe/users/rye", _, _, Accept: "application/activity+json") do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/rye.json")
     }}
  end

  def get("http://mastodon.example.org/users/admin/statuses/100787282858396771", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body:
         File.read!(
           "test/fixtures/tesla_mock/http___mastodon.example.org_users_admin_status_1234.json"
         )
     }}
  end

  def get("https://puckipedia.com/", _, _, Accept: "application/activity+json") do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/puckipedia.com.json")
     }}
  end

  def get("https://peertube.moe/accounts/7even", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/7even.json")
     }}
  end

  def get("https://peertube.moe/videos/watch/df5f464b-be8d-46fb-ad81-2d4c2d1630e3", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/peertube.moe-vid.json")
     }}
  end

  def get("https://mobilizon.org/events/252d5816-00a3-4a89-a66f-15bf65c33e39", _, _,
        Accept: "application/activity+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mobilizon.org-event.json")
     }}
  end

  def get("https://mobilizon.org/@tcit", _, _, Accept: "application/activity+json") do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mobilizon.org-user.json")
     }}
  end

  def get("https://baptiste.gelez.xyz/@/BaptisteGelez", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/baptiste.gelex.xyz-user.json")
     }}
  end

  def get("https://baptiste.gelez.xyz/~/PlumeDevelopment/this-month-in-plume-june-2018/", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/baptiste.gelex.xyz-article.json")
     }}
  end

  def get("https://wedistribute.org/wp-json/pterotype/v1/object/85810", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/wedistribute-article.json")
     }}
  end

  def get("https://wedistribute.org/wp-json/pterotype/v1/actor/-blog", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/wedistribute-user.json")
     }}
  end

  def get("http://mastodon.example.org/users/admin", _, _, Accept: "application/activity+json") do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/admin@mastdon.example.org.json")
     }}
  end

  def get("http://mastodon.example.org/users/relay", _, _, Accept: "application/activity+json") do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/relay@mastdon.example.org.json")
     }}
  end

  def get("http://mastodon.example.org/users/gargron", _, _, Accept: "application/activity+json") do
    {:error, :nxdomain}
  end

  def get("http://osada.macgirvin.com/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 404,
       body: ""
     }}
  end

  def get("https://osada.macgirvin.com/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 404,
       body: ""
     }}
  end

  def get("http://mastodon.sdf.org/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/sdf.org_host_meta")
     }}
  end

  def get("https://mastodon.sdf.org/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/sdf.org_host_meta")
     }}
  end

  def get(
        "https://mastodon.sdf.org/.well-known/webfinger?resource=https://mastodon.sdf.org/users/snowdusk",
        _,
        _,
        _
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/snowdusk@sdf.org_host_meta.json")
     }}
  end

  def get("http://mstdn.jp/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mstdn.jp_host_meta")
     }}
  end

  def get("https://mstdn.jp/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mstdn.jp_host_meta")
     }}
  end

  def get("https://mstdn.jp/.well-known/webfinger?resource=kpherox@mstdn.jp", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/kpherox@mstdn.jp.xml")
     }}
  end

  def get("http://mamot.fr/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mamot.fr_host_meta")
     }}
  end

  def get("https://mamot.fr/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mamot.fr_host_meta")
     }}
  end

  def get(
        "https://mamot.fr/.well-known/webfinger?resource=https://mamot.fr/users/Skruyb",
        _,
        _,
        _
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/skruyb@mamot.fr.atom")
     }}
  end

  def get("http://pawoo.net/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/pawoo.net_host_meta")
     }}
  end

  def get("https://pawoo.net/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/pawoo.net_host_meta")
     }}
  end

  def get(
        "https://pawoo.net/.well-known/webfinger?resource=https://pawoo.net/users/pekorino",
        _,
        _,
        _
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/pekorino@pawoo.net_host_meta.json")
     }}
  end

  def get("http://zetsubou.xn--q9jyb4c/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/xn--q9jyb4c_host_meta")
     }}
  end

  def get("https://zetsubou.xn--q9jyb4c/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/xn--q9jyb4c_host_meta")
     }}
  end

  def get("http://pleroma.soykaf.com/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/soykaf.com_host_meta")
     }}
  end

  def get("https://pleroma.soykaf.com/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/soykaf.com_host_meta")
     }}
  end

  def get("http://social.stopwatchingus-heidelberg.de/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/stopwatchingus-heidelberg.de_host_meta")
     }}
  end

  def get("https://social.stopwatchingus-heidelberg.de/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/stopwatchingus-heidelberg.de_host_meta")
     }}
  end

  def get(
        "http://mastodon.example.org/@admin/99541947525187367",
        _,
        _,
        Accept: "application/activity+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/mastodon-note-object.json")
     }}
  end

  def get("http://mastodon.example.org/@admin/99541947525187368", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 404,
       body: ""
     }}
  end

  def get("https://shitposter.club/notice/7369654", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/7369654.html")
     }}
  end

  def get("https://mstdn.io/users/mayuutann", _, _, Accept: "application/activity+json") do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mayumayu.json")
     }}
  end

  def get(
        "https://mstdn.io/users/mayuutann/statuses/99568293732299394",
        _,
        _,
        Accept: "application/activity+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mayumayupost.json")
     }}
  end

  def get("https://pleroma.soykaf.com/users/lain/feed.atom", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body:
         File.read!(
           "test/fixtures/tesla_mock/https___pleroma.soykaf.com_users_lain_feed.atom.xml"
         )
     }}
  end

  def get(url, _, _, Accept: "application/xrd+xml,application/jrd+json")
      when url in [
             "https://pleroma.soykaf.com/.well-known/webfinger?resource=acct:https://pleroma.soykaf.com/users/lain",
             "https://pleroma.soykaf.com/.well-known/webfinger?resource=https://pleroma.soykaf.com/users/lain"
           ] do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___pleroma.soykaf.com_users_lain.xml")
     }}
  end

  def get("https://shitposter.club/api/statuses/user_timeline/1.atom", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body:
         File.read!(
           "test/fixtures/tesla_mock/https___shitposter.club_api_statuses_user_timeline_1.atom.xml"
         )
     }}
  end

  def get(
        "https://shitposter.club/.well-known/webfinger?resource=https://shitposter.club/user/1",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___shitposter.club_user_1.xml")
     }}
  end

  def get("https://shitposter.club/notice/2827873", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___shitposter.club_notice_2827873.json")
     }}
  end

  def get("https://shitposter.club/api/statuses/show/2827873.atom", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body:
         File.read!(
           "test/fixtures/tesla_mock/https___shitposter.club_api_statuses_show_2827873.atom.xml"
         )
     }}
  end

  def get("https://testing.pleroma.lol/objects/b319022a-4946-44c5-9de9-34801f95507b", _, _, _) do
    {:ok, %Tesla.Env{status: 200}}
  end

  def get("https://shitposter.club/api/statuses/user_timeline/5381.atom", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/spc_5381.atom")
     }}
  end

  def get(
        "https://shitposter.club/.well-known/webfinger?resource=https://shitposter.club/user/5381",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/spc_5381_xrd.xml")
     }}
  end

  def get("http://shitposter.club/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/shitposter.club_host_meta")
     }}
  end

  def get("https://shitposter.club/api/statuses/show/7369654.atom", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/7369654.atom")
     }}
  end

  def get("https://shitposter.club/notice/4027863", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/7369654.html")
     }}
  end

  def get("https://social.sakamoto.gq/users/eal/feed.atom", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/sakamoto_eal_feed.atom")
     }}
  end

  def get("http://social.sakamoto.gq/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/social.sakamoto.gq_host_meta")
     }}
  end

  def get(
        "https://social.sakamoto.gq/.well-known/webfinger?resource=https://social.sakamoto.gq/users/eal",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/eal_sakamoto.xml")
     }}
  end

  def get(
        "https://social.sakamoto.gq/objects/0ccc1a2c-66b0-4305-b23a-7f7f2b040056",
        _,
        _,
        Accept: "application/atom+xml"
      ) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/tesla_mock/sakamoto.atom")}}
  end

  def get("http://mastodon.social/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mastodon.social_host_meta")
     }}
  end

  def get(
        "https://mastodon.social/.well-known/webfinger?resource=https://mastodon.social/users/lambadalambda",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body:
         File.read!("test/fixtures/tesla_mock/https___mastodon.social_users_lambadalambda.xml")
     }}
  end

  def get("http://gs.example.org/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/gs.example.org_host_meta")
     }}
  end

  def get(
        "http://gs.example.org/.well-known/webfinger?resource=http://gs.example.org:4040/index.php/user/1",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body:
         File.read!("test/fixtures/tesla_mock/http___gs.example.org_4040_index.php_user_1.xml")
     }}
  end

  def get(
        "http://gs.example.org:4040/index.php/user/1",
        _,
        _,
        Accept: "application/activity+json"
      ) do
    {:ok, %Tesla.Env{status: 406, body: ""}}
  end

  def get("http://gs.example.org/index.php/api/statuses/user_timeline/1.atom", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body:
         File.read!(
           "test/fixtures/tesla_mock/http__gs.example.org_index.php_api_statuses_user_timeline_1.atom.xml"
         )
     }}
  end

  def get("https://social.heldscal.la/api/statuses/user_timeline/29191.atom", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body:
         File.read!(
           "test/fixtures/tesla_mock/https___social.heldscal.la_api_statuses_user_timeline_29191.atom.xml"
         )
     }}
  end

  def get("http://squeet.me/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{status: 200, body: File.read!("test/fixtures/tesla_mock/squeet.me_host_meta")}}
  end

  def get(
        "https://squeet.me/xrd?uri=lain@squeet.me",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/lain_squeet.me_webfinger.xml")
     }}
  end

  def get(
        "https://social.heldscal.la/.well-known/webfinger?resource=shp@social.heldscal.la",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/shp@social.heldscal.la.xml")
     }}
  end

  def get(
        "https://social.heldscal.la/.well-known/webfinger?resource=invalid_content@social.heldscal.la",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok, %Tesla.Env{status: 200, body: ""}}
  end

  def get("http://framatube.org/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/framatube.org_host_meta")
     }}
  end

  def get(
        "http://framatube.org/main/xrd?uri=framasoft@framatube.org",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       headers: [{"content-type", "application/json"}],
       body: File.read!("test/fixtures/tesla_mock/framasoft@framatube.org.json")
     }}
  end

  def get("http://gnusocial.de/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/gnusocial.de_host_meta")
     }}
  end

  def get(
        "http://gnusocial.de/main/xrd?uri=winterdienst@gnusocial.de",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/winterdienst_webfinger.json")
     }}
  end

  def get("http://status.alpicola.com/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/status.alpicola.com_host_meta")
     }}
  end

  def get("http://macgirvin.com/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/macgirvin.com_host_meta")
     }}
  end

  def get("http://gerzilla.de/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/gerzilla.de_host_meta")
     }}
  end

  def get(
        "https://gerzilla.de/xrd/?uri=kaniini@gerzilla.de",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       headers: [{"content-type", "application/json"}],
       body: File.read!("test/fixtures/tesla_mock/kaniini@gerzilla.de.json")
     }}
  end

  def get("https://social.heldscal.la/api/statuses/user_timeline/23211.atom", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body:
         File.read!(
           "test/fixtures/tesla_mock/https___social.heldscal.la_api_statuses_user_timeline_23211.atom.xml"
         )
     }}
  end

  def get(
        "https://social.heldscal.la/.well-known/webfinger?resource=https://social.heldscal.la/user/23211",
        _,
        _,
        _
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___social.heldscal.la_user_23211.xml")
     }}
  end

  def get("http://social.heldscal.la/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/social.heldscal.la_host_meta")
     }}
  end

  def get("https://social.heldscal.la/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/social.heldscal.la_host_meta")
     }}
  end

  def get("https://mastodon.social/users/lambadalambda.atom", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/lambadalambda.atom")}}
  end

  def get("https://mastodon.social/users/lambadalambda", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/lambadalambda.json")}}
  end

  def get("https://apfed.club/channel/indio", _, _, _) do
    {:ok,
     %Tesla.Env{status: 200, body: File.read!("test/fixtures/tesla_mock/osada-user-indio.json")}}
  end

  def get("https://social.heldscal.la/user/23211", _, _, Accept: "application/activity+json") do
    {:ok, Tesla.Mock.json(%{"id" => "https://social.heldscal.la/user/23211"}, status: 200)}
  end

  def get("http://example.com/ogp", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/rich_media/ogp.html")}}
  end

  def get("https://example.com/ogp", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/rich_media/ogp.html")}}
  end

  def get("https://pleroma.local/notice/9kCP7V", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/rich_media/ogp.html")}}
  end

  def get("http://localhost:4001/users/masto_closed/followers", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/users_mock/masto_closed_followers.json")
     }}
  end

  def get("http://localhost:4001/users/masto_closed/followers?page=1", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/users_mock/masto_closed_followers_page.json")
     }}
  end

  def get("http://localhost:4001/users/masto_closed/following", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/users_mock/masto_closed_following.json")
     }}
  end

  def get("http://localhost:4001/users/masto_closed/following?page=1", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/users_mock/masto_closed_following_page.json")
     }}
  end

  def get("http://localhost:8080/followers/fuser3", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/users_mock/friendica_followers.json")
     }}
  end

  def get("http://localhost:8080/following/fuser3", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/users_mock/friendica_following.json")
     }}
  end

  def get("http://localhost:4001/users/fuser2/followers", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/users_mock/pleroma_followers.json")
     }}
  end

  def get("http://localhost:4001/users/fuser2/following", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/users_mock/pleroma_following.json")
     }}
  end

  def get("http://domain-with-errors:4001/users/fuser1/followers", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 504,
       body: ""
     }}
  end

  def get("http://domain-with-errors:4001/users/fuser1/following", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 504,
       body: ""
     }}
  end

  def get("http://example.com/ogp-missing-data", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/rich_media/ogp-missing-data.html")
     }}
  end

  def get("https://example.com/ogp-missing-data", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/rich_media/ogp-missing-data.html")
     }}
  end

  def get("http://example.com/malformed", _, _, _) do
    {:ok,
     %Tesla.Env{status: 200, body: File.read!("test/fixtures/rich_media/malformed-data.html")}}
  end

  def get("http://example.com/empty", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: "hello"}}
  end

  def get("http://404.site" <> _, _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 404,
       body: ""
     }}
  end

  def get(
        "https://zetsubou.xn--q9jyb4c/.well-known/webfinger?resource=lain@zetsubou.xn--q9jyb4c",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/lain.xml")
     }}
  end

  def get(
        "https://zetsubou.xn--q9jyb4c/.well-known/webfinger?resource=https://zetsubou.xn--q9jyb4c/users/lain",
        _,
        _,
        Accept: "application/xrd+xml,application/jrd+json"
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/lain.xml")
     }}
  end

  def get(
        "https://zetsubou.xn--q9jyb4c/.well-known/host-meta",
        _,
        _,
        _
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/host-meta-zetsubou.xn--q9jyb4c.xml")
     }}
  end

  def get("https://info.pleroma.site/activity.json", _, _, Accept: "application/activity+json") do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https__info.pleroma.site_activity.json")
     }}
  end

  def get("https://info.pleroma.site/activity.json", _, _, _) do
    {:ok, %Tesla.Env{status: 404, body: ""}}
  end

  def get("https://info.pleroma.site/activity2.json", _, _, Accept: "application/activity+json") do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https__info.pleroma.site_activity2.json")
     }}
  end

  def get("https://info.pleroma.site/activity2.json", _, _, _) do
    {:ok, %Tesla.Env{status: 404, body: ""}}
  end

  def get("https://info.pleroma.site/activity3.json", _, _, Accept: "application/activity+json") do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https__info.pleroma.site_activity3.json")
     }}
  end

  def get("https://info.pleroma.site/activity3.json", _, _, _) do
    {:ok, %Tesla.Env{status: 404, body: ""}}
  end

  def get("https://mstdn.jp/.well-known/webfinger?resource=acct:kpherox@mstdn.jp", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/kpherox@mstdn.jp.xml")
     }}
  end

  def get("https://10.111.10.1/notice/9kCP7V", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: ""}}
  end

  def get("https://172.16.32.40/notice/9kCP7V", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: ""}}
  end

  def get("https://192.168.10.40/notice/9kCP7V", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: ""}}
  end

  def get("https://www.patreon.com/posts/mastodon-2-9-and-28121681", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: ""}}
  end

  def get("http://mastodon.example.org/@admin/99541947525187367", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/mastodon-post-activity.json")}}
  end

  def get("https://info.pleroma.site/activity4.json", _, _, _) do
    {:ok, %Tesla.Env{status: 500, body: "Error occurred"}}
  end

  def get("http://example.com/rel_me/anchor", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/rel_me_anchor.html")}}
  end

  def get("http://example.com/rel_me/anchor_nofollow", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/rel_me_anchor_nofollow.html")}}
  end

  def get("http://example.com/rel_me/link", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/rel_me_link.html")}}
  end

  def get("http://example.com/rel_me/null", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/rel_me_null.html")}}
  end

  def get("https://skippers-bin.com/notes/7x9tmrp97i", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/misskey_poll_no_end_date.json")
     }}
  end

  def get("https://skippers-bin.com/users/7v1w1r8ce6", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/tesla_mock/sjw.json")}}
  end

  def get("https://patch.cx/users/rin", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/tesla_mock/rin.json")}}
  end

  def get("http://example.com/rel_me/error", _, _, _) do
    {:ok, %Tesla.Env{status: 404, body: ""}}
  end

  def get(url, query, body, headers) do
    {:error,
     "Mock response not implemented for GET #{inspect(url)}, #{query}, #{inspect(body)}, #{
       inspect(headers)
     }"}
  end

  # POST Requests
  #

  def post(url, query \\ [], body \\ [], headers \\ [])

  def post("http://example.org/needs_refresh", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: ""
     }}
  end

  def post("http://mastodon.example.org/inbox", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: ""
     }}
  end

  def post("https://hubzilla.example.org/inbox", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: ""
     }}
  end

  def post("http://gs.example.org/index.php/main/salmon/user/1", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: ""
     }}
  end

  def post("http://200.site" <> _, _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: ""
     }}
  end

  def post("http://connrefused.site" <> _, _, _, _) do
    {:error, :connrefused}
  end

  def post("http://404.site" <> _, _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 404,
       body: ""
     }}
  end

  def post(url, query, body, headers) do
    {:error,
     "Mock response not implemented for POST #{inspect(url)}, #{query}, #{inspect(body)}, #{
       inspect(headers)
     }"}
  end
end
