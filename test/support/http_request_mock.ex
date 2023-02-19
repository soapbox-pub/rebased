# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule HttpRequestMock do
  require Logger

  def activitypub_object_headers, do: [{"content-type", "application/activity+json"}]

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
       body: File.read!("test/fixtures/tesla_mock/https___osada.macgirvin.com_channel_mike.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://shitposter.club/users/moonman", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/moonman@shitposter.club.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://mastodon.social/users/emelie/statuses/101849165031453009", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/status.emelie.json"),
       headers: activitypub_object_headers()
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
       body: File.read!("test/fixtures/tesla_mock/emelie.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://mastodon.social/users/not_found", _, _, _) do
    {:ok, %Tesla.Env{status: 404}}
  end

  def get("https://mastodon.sdf.org/users/rinpatch", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/rinpatch.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://mastodon.sdf.org/users/rinpatch/collections/featured", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body:
         File.read!("test/fixtures/users_mock/masto_featured.json")
         |> String.replace("{{domain}}", "mastodon.sdf.org")
         |> String.replace("{{nickname}}", "rinpatch"),
       headers: [{"content-type", "application/activity+json"}]
     }}
  end

  def get("https://patch.cx/objects/tesla_mock/poll_attachment", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/poll_attachment.json"),
       headers: activitypub_object_headers()
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
       body: File.read!("test/fixtures/tesla_mock/webfinger_emelie.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get(
        "https://osada.macgirvin.com/.well-known/webfinger?resource=acct:mike@osada.macgirvin.com",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mike@osada.macgirvin.com.json"),
       headers: [{"content-type", "application/jrd+json"}]
     }}
  end

  def get(
        "https://social.heldscal.la/.well-known/webfinger?resource=https://social.heldscal.la/user/29191",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___social.heldscal.la_user_29191.xml")
     }}
  end

  def get(
        "https://pawoo.net/.well-known/webfinger?resource=acct:https://pawoo.net/users/pekorino",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___pawoo.net_users_pekorino.xml")
     }}
  end

  def get(
        "https://social.stopwatchingus-heidelberg.de/.well-known/webfinger?resource=acct:https://social.stopwatchingus-heidelberg.de/user/18330",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/atarifrosch_webfinger.xml")
     }}
  end

  def get(
        "https://social.heldscal.la/.well-known/webfinger?resource=nonexistant@social.heldscal.la",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/nonexistant@social.heldscal.la.xml")
     }}
  end

  def get(
        "https://squeet.me/xrd/?uri=acct:lain@squeet.me",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/lain_squeet.me_webfinger.xml"),
       headers: [{"content-type", "application/xrd+xml"}]
     }}
  end

  def get(
        "https://mst3k.interlinked.me/users/luciferMysticus",
        _,
        _,
        [{"accept", "application/activity+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/lucifermysticus.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://prismo.news/@mxb", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___prismo.news__mxb.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get(
        "https://hubzilla.example.org/channel/kaniini",
        _,
        _,
        [{"accept", "application/activity+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/kaniini@hubzilla.example.org.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://niu.moe/users/rye", _, _, [{"accept", "application/activity+json"}]) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/rye.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://n1u.moe/users/rye", _, _, [{"accept", "application/activity+json"}]) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/rye.json"),
       headers: activitypub_object_headers()
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

  def get("https://puckipedia.com/", _, _, [{"accept", "application/activity+json"}]) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/puckipedia.com.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://peertube.moe/accounts/7even", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/7even.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://peertube.stream/accounts/createurs", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/peertube/actor-person.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://peertube.moe/videos/watch/df5f464b-be8d-46fb-ad81-2d4c2d1630e3", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/peertube.moe-vid.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://framatube.org/accounts/framasoft", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___framatube.org_accounts_framasoft.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://framatube.org/videos/watch/6050732a-8a7a-43d4-a6cd-809525a1d206", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/framatube.org-video.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://peertube.social/accounts/craigmaloney", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/craigmaloney.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://peertube.social/videos/watch/278d2b7c-0f38-4aaa-afe6-9ecc0c4a34fe", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/peertube-social.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://mobilizon.org/events/252d5816-00a3-4a89-a66f-15bf65c33e39", _, _, [
        {"accept", "application/activity+json"}
      ]) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mobilizon.org-event.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://mobilizon.org/@tcit", _, _, [{"accept", "application/activity+json"}]) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mobilizon.org-user.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://baptiste.gelez.xyz/@/BaptisteGelez", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/baptiste.gelex.xyz-user.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://baptiste.gelez.xyz/~/PlumeDevelopment/this-month-in-plume-june-2018/", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/baptiste.gelex.xyz-article.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://wedistribute.org/wp-json/pterotype/v1/object/85810", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/wedistribute-article.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://wedistribute.org/wp-json/pterotype/v1/actor/-blog", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/wedistribute-user.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("http://mastodon.example.org/users/admin", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/admin@mastdon.example.org.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("http://mastodon.example.org/users/relay", _, _, [
        {"accept", "application/activity+json"}
      ]) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/relay@mastdon.example.org.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("http://mastodon.example.org/users/gargron", _, _, [
        {"accept", "application/activity+json"}
      ]) do
    {:error, :nxdomain}
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
       body: File.read!("test/fixtures/tesla_mock/pekorino@pawoo.net_host_meta.json"),
       headers: activitypub_object_headers()
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
        _
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/mastodon-note-object.json"),
       headers: activitypub_object_headers()
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

  def get("https://mstdn.io/users/mayuutann", _, _, [{"accept", "application/activity+json"}]) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mayumayu.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get(
        "https://mstdn.io/users/mayuutann/statuses/99568293732299394",
        _,
        _,
        [{"accept", "application/activity+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mayumayupost.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get(url, _, _, [{"accept", "application/xrd+xml,application/jrd+json"}])
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

  def get(
        "https://shitposter.club/.well-known/webfinger?resource=https://shitposter.club/user/1",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___shitposter.club_user_1.xml")
     }}
  end

  def get("https://testing.pleroma.lol/objects/b319022a-4946-44c5-9de9-34801f95507b", _, _, _) do
    {:ok, %Tesla.Env{status: 200}}
  end

  def get(
        "https://shitposter.club/.well-known/webfinger?resource=https://shitposter.club/user/5381",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
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

  def get("https://shitposter.club/notice/4027863", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/7369654.html")
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
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/eal_sakamoto.xml")
     }}
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
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body:
         File.read!("test/fixtures/tesla_mock/https___mastodon.social_users_lambadalambda.xml")
     }}
  end

  def get(
        "https://mastodon.social/.well-known/webfinger?resource=acct:not_found@mastodon.social",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok, %Tesla.Env{status: 404}}
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
        [{"accept", "application/xrd+xml,application/jrd+json"}]
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
        [{"accept", "application/activity+json"}]
      ) do
    {:ok, %Tesla.Env{status: 406, body: ""}}
  end

  def get("https://squeet.me/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{status: 200, body: File.read!("test/fixtures/tesla_mock/squeet.me_host_meta")}}
  end

  def get(
        "https://squeet.me/xrd?uri=lain@squeet.me",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/lain_squeet.me_webfinger.xml")
     }}
  end

  def get(
        "https://social.heldscal.la/.well-known/webfinger?resource=acct:shp@social.heldscal.la",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/shp@social.heldscal.la.xml"),
       headers: [{"content-type", "application/xrd+xml"}]
     }}
  end

  def get(
        "https://social.heldscal.la/.well-known/webfinger?resource=acct:invalid_content@social.heldscal.la",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok, %Tesla.Env{status: 200, body: "", headers: [{"content-type", "application/jrd+json"}]}}
  end

  def get("https://framatube.org/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/framatube.org_host_meta")
     }}
  end

  def get(
        "https://framatube.org/main/xrd?uri=acct:framasoft@framatube.org",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       headers: [{"content-type", "application/jrd+json"}],
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
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/winterdienst_webfinger.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://status.alpicola.com/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/status.alpicola.com_host_meta")
     }}
  end

  def get("https://macgirvin.com/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/macgirvin.com_host_meta")
     }}
  end

  def get("https://gerzilla.de/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/gerzilla.de_host_meta")
     }}
  end

  def get(
        "https://gerzilla.de/xrd/?uri=acct:kaniini@gerzilla.de",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       headers: [{"content-type", "application/jrd+json"}],
       body: File.read!("test/fixtures/tesla_mock/kaniini@gerzilla.de.json")
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

  def get("https://mastodon.social/users/lambadalambda", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/lambadalambda.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://mastodon.social/users/lambadalambda/collections/featured", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body:
         File.read!("test/fixtures/users_mock/masto_featured.json")
         |> String.replace("{{domain}}", "mastodon.social")
         |> String.replace("{{nickname}}", "lambadalambda"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://apfed.club/channel/indio", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/osada-user-indio.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://social.heldscal.la/user/23211", _, _, [{"accept", "application/activity+json"}]) do
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
       body: File.read!("test/fixtures/users_mock/masto_closed_followers.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("http://localhost:4001/users/masto_closed/followers?page=1", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/users_mock/masto_closed_followers_page.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("http://localhost:4001/users/masto_closed/following", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/users_mock/masto_closed_following.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("http://localhost:4001/users/masto_closed/following?page=1", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/users_mock/masto_closed_following_page.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("http://localhost:8080/followers/fuser3", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/users_mock/friendica_followers.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("http://localhost:8080/following/fuser3", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/users_mock/friendica_following.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("http://localhost:4001/users/fuser2/followers", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/users_mock/pleroma_followers.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("http://localhost:4001/users/fuser2/following", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/users_mock/pleroma_following.json"),
       headers: activitypub_object_headers()
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

  def get("https://404.site" <> _, _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 404,
       body: ""
     }}
  end

  def get(
        "https://zetsubou.xn--q9jyb4c/.well-known/webfinger?resource=acct:lain@zetsubou.xn--q9jyb4c",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/lain.xml"),
       headers: [{"content-type", "application/xrd+xml"}]
     }}
  end

  def get(
        "https://zetsubou.xn--q9jyb4c/.well-known/webfinger?resource=acct:https://zetsubou.xn--q9jyb4c/users/lain",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/lain.xml"),
       headers: [{"content-type", "application/xrd+xml"}]
     }}
  end

  def get("http://zetsubou.xn--q9jyb4c/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/host-meta-zetsubou.xn--q9jyb4c.xml")
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

  def get("http://lm.kazv.moe/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/lm.kazv.moe_host_meta")
     }}
  end

  def get("https://lm.kazv.moe/.well-known/host-meta", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/lm.kazv.moe_host_meta")
     }}
  end

  def get(
        "https://lm.kazv.moe/.well-known/webfinger?resource=acct:mewmew@lm.kazv.moe",
        _,
        _,
        [{"accept", "application/xrd+xml,application/jrd+json"}]
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___lm.kazv.moe_users_mewmew.xml"),
       headers: [{"content-type", "application/xrd+xml"}]
     }}
  end

  def get("https://lm.kazv.moe/users/mewmew", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mewmew@lm.kazv.moe.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://lm.kazv.moe/users/mewmew/collections/featured", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body:
         File.read!("test/fixtures/users_mock/masto_featured.json")
         |> String.replace("{{domain}}", "lm.kazv.moe")
         |> String.replace("{{nickname}}", "mewmew"),
       headers: [{"content-type", "application/activity+json"}]
     }}
  end

  def get("https://info.pleroma.site/activity.json", _, _, [
        {"accept", "application/activity+json"}
      ]) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https__info.pleroma.site_activity.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://info.pleroma.site/activity.json", _, _, _) do
    {:ok, %Tesla.Env{status: 404, body: ""}}
  end

  def get("https://info.pleroma.site/activity2.json", _, _, [
        {"accept", "application/activity+json"}
      ]) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https__info.pleroma.site_activity2.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://info.pleroma.site/activity2.json", _, _, _) do
    {:ok, %Tesla.Env{status: 404, body: ""}}
  end

  def get("https://info.pleroma.site/activity3.json", _, _, [
        {"accept", "application/activity+json"}
      ]) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https__info.pleroma.site_activity3.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://info.pleroma.site/activity3.json", _, _, _) do
    {:ok, %Tesla.Env{status: 404, body: ""}}
  end

  def get("https://mstdn.jp/.well-known/webfinger?resource=acct:kpherox@mstdn.jp", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/kpherox@mstdn.jp.xml"),
       headers: [{"content-type", "application/xrd+xml"}]
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
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/mastodon-post-activity.json"),
       headers: activitypub_object_headers()
     }}
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
       body: File.read!("test/fixtures/tesla_mock/misskey_poll_no_end_date.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://example.org/emoji/firedfox.png", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/image.jpg")}}
  end

  def get("https://skippers-bin.com/users/7v1w1r8ce6", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/sjw.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://patch.cx/users/rin", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/rin.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get(
        "https://channels.tests.funkwhale.audio/federation/music/uploads/42342395-0208-4fee-a38d-259a6dae0871",
        _,
        _,
        _
      ) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/funkwhale_audio.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://channels.tests.funkwhale.audio/federation/actors/compositions", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/funkwhale_channel.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("http://example.com/rel_me/error", _, _, _) do
    {:ok, %Tesla.Env{status: 404, body: ""}}
  end

  def get("https://relay.mastodon.host/actor", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/relay/relay.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("http://localhost:4001/", _, "", [{"accept", "text/html"}]) do
    {:ok, %Tesla.Env{status: 200, body: File.read!("test/fixtures/tesla_mock/7369654.html")}}
  end

  def get("https://osada.macgirvin.com/", _, "", [{"accept", "text/html"}]) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/https___osada.macgirvin.com.html")
     }}
  end

  def get("https://patch.cx/objects/a399c28e-c821-4820-bc3e-4afeb044c16f", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/emoji-in-summary.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://gleasonator.com/objects/102eb097-a18b-4cd5-abfc-f952efcb70bb", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/gleasonator-AG3RzWfwEKKrY63qj2.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://gleasonator.com/users/macgirvin", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/macgirvin@gleasonator.com.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://gleasonator.com/users/macgirvin/collections/featured", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body:
         File.read!("test/fixtures/users_mock/masto_featured.json")
         |> String.replace("{{domain}}", "gleasonator.com")
         |> String.replace("{{nickname}}", "macgirvin"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://mk.absturztau.be/users/8ozbzjs3o8", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mametsuko@mk.absturztau.be.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://p.helene.moe/users/helene", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/helene@p.helene.moe.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://mk.absturztau.be/notes/93e7nm8wqg", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mk.absturztau.be-93e7nm8wqg.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://mk.absturztau.be/notes/93e7nm8wqg/activity", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/mk.absturztau.be-93e7nm8wqg-activity.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get("https://p.helene.moe/objects/fd5910ac-d9dc-412e-8d1d-914b203296c4", _, _, _) do
    {:ok,
     %Tesla.Env{
       status: 200,
       body: File.read!("test/fixtures/tesla_mock/p.helene.moe-AM7S6vZQmL6pI9TgPY.json"),
       headers: activitypub_object_headers()
     }}
  end

  def get(url, query, body, headers) do
    {:error,
     "Mock response not implemented for GET #{inspect(url)}, #{query}, #{inspect(body)}, #{inspect(headers)}"}
  end

  # POST Requests
  #

  def post(url, query \\ [], body \\ [], headers \\ [])

  def post("https://relay.mastodon.host/inbox", _, _, _) do
    {:ok, %Tesla.Env{status: 200, body: ""}}
  end

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
     "Mock response not implemented for POST #{inspect(url)}, #{query}, #{inspect(body)}, #{inspect(headers)}"}
  end

  # Most of the rich media mocks are missing HEAD requests, so we just return 404.
  @rich_media_mocks [
    "https://example.com/ogp",
    "https://example.com/ogp-missing-data",
    "https://example.com/twitter-card"
  ]
  def head(url, _query, _body, _headers) when url in @rich_media_mocks do
    {:ok, %Tesla.Env{status: 404, body: ""}}
  end

  def head(url, query, body, headers) do
    {:error,
     "Mock response not implemented for HEAD #{inspect(url)}, #{query}, #{inspect(body)}, #{inspect(headers)}"}
  end
end
