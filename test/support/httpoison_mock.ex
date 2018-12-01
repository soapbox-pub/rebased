defmodule HTTPoisonMock do
  alias HTTPoison.Response

  def process_request_options(options), do: options

  def get(url, body \\ [], headers \\ [])

  def get("https://prismo.news/@mxb", _, _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https___prismo.news__mxb.json")
     }}
  end

  def get("https://osada.macgirvin.com/channel/mike", _, _) do
    {:ok,
     %Response{
       status_code: 200,
       body:
         File.read!("test/fixtures/httpoison_mock/https___osada.macgirvin.com_channel_mike.json")
     }}
  end

  def get(
        "https://osada.macgirvin.com/.well-known/webfinger?resource=acct:mike@osada.macgirvin.com",
        _,
        _
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/mike@osada.macgirvin.com.json")
     }}
  end

  def get("https://info.pleroma.site/activity.json", _, _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https__info.pleroma.site_activity.json")
     }}
  end

  def get("https://info.pleroma.site/activity2.json", _, _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https__info.pleroma.site_activity2.json")
     }}
  end

  def get("https://info.pleroma.site/activity3.json", _, _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https__info.pleroma.site_activity3.json")
     }}
  end

  def get("https://info.pleroma.site/activity4.json", _, _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https__info.pleroma.site_activity4.json")
     }}
  end

  def get("https://info.pleroma.site/actor.json", _, _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https___info.pleroma.site_actor.json")
     }}
  end

  def get("https://puckipedia.com/", [Accept: "application/activity+json"], _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/puckipedia.com.json")
     }}
  end

  def get(
        "https://gerzilla.de/.well-known/webfinger?resource=acct:kaniini@gerzilla.de",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/kaniini@gerzilla.de.json")
     }}
  end

  def get(
        "https://framatube.org/.well-known/webfinger?resource=acct:framasoft@framatube.org",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/framasoft@framatube.org.json")
     }}
  end

  def get(
        "https://gnusocial.de/.well-known/webfinger?resource=acct:winterdienst@gnusocial.de",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/winterdienst_webfinger.json")
     }}
  end

  def get(
        "https://social.heldscal.la/.well-known/webfinger",
        [Accept: "application/xrd+xml,application/jrd+json"],
        params: [resource: "nonexistant@social.heldscal.la"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 500,
       body: File.read!("test/fixtures/httpoison_mock/nonexistant@social.heldscal.la.xml")
     }}
  end

  def get(
        "https://social.heldscal.la/.well-known/webfinger?resource=shp@social.heldscal.la",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/shp@social.heldscal.la.xml")
     }}
  end

  def get(
        "https://social.heldscal.la/.well-known/webfinger",
        [Accept: "application/xrd+xml,application/jrd+json"],
        params: [resource: "shp@social.heldscal.la"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/shp@social.heldscal.la.xml")
     }}
  end

  def get(
        "https://social.heldscal.la/.well-known/webfinger",
        [Accept: "application/xrd+xml,application/jrd+json"],
        params: [resource: "https://social.heldscal.la/user/23211"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https___social.heldscal.la_user_23211.xml")
     }}
  end

  def get(
        "https://social.heldscal.la/.well-known/webfinger?resource=https://social.heldscal.la/user/23211",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https___social.heldscal.la_user_23211.xml")
     }}
  end

  def get(
        "https://social.heldscal.la/.well-known/webfinger",
        [Accept: "application/xrd+xml,application/jrd+json"],
        params: [resource: "https://social.heldscal.la/user/29191"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https___social.heldscal.la_user_29191.xml")
     }}
  end

  def get(
        "https://social.heldscal.la/.well-known/webfinger?resource=https://social.heldscal.la/user/29191",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https___social.heldscal.la_user_29191.xml")
     }}
  end

  def get(
        "https://mastodon.social/.well-known/webfinger",
        [Accept: "application/xrd+xml,application/jrd+json"],
        params: [resource: "https://mastodon.social/users/lambadalambda"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body:
         File.read!(
           "test/fixtures/httpoison_mock/https___mastodon.social_users_lambadalambda.xml"
         )
     }}
  end

  def get(
        "https://mastodon.social/.well-known/webfinger?resource=https://mastodon.social/users/lambadalambda",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body:
         File.read!(
           "test/fixtures/httpoison_mock/https___mastodon.social_users_lambadalambda.xml"
         )
     }}
  end

  def get(
        "https://shitposter.club/.well-known/webfinger",
        [Accept: "application/xrd+xml,application/jrd+json"],
        params: [resource: "https://shitposter.club/user/1"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https___shitposter.club_user_1.xml")
     }}
  end

  def get(
        "https://shitposter.club/.well-known/webfinger?resource=https://shitposter.club/user/1",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https___shitposter.club_user_1.xml")
     }}
  end

  def get(
        "https://shitposter.club/.well-known/webfinger?resource=https://shitposter.club/user/5381",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/spc_5381_xrd.xml")
     }}
  end

  def get(
        "http://gs.example.org/.well-known/webfinger",
        [Accept: "application/xrd+xml,application/jrd+json"],
        params: [resource: "http://gs.example.org:4040/index.php/user/1"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body:
         File.read!(
           "test/fixtures/httpoison_mock/http___gs.example.org_4040_index.php_user_1.xml"
         )
     }}
  end

  def get(
        "http://gs.example.org/.well-known/webfinger?resource=http://gs.example.org:4040/index.php/user/1",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body:
         File.read!(
           "test/fixtures/httpoison_mock/http___gs.example.org_4040_index.php_user_1.xml"
         )
     }}
  end

  def get(
        "https://social.stopwatchingus-heidelberg.de/.well-known/webfinger?resource=https://social.stopwatchingus-heidelberg.de/user/18330",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/atarifrosch_webfinger.xml")
     }}
  end

  def get(
        "https://pleroma.soykaf.com/.well-known/webfinger",
        [Accept: "application/xrd+xml,application/jrd+json"],
        params: [resource: "https://pleroma.soykaf.com/users/lain"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https___pleroma.soykaf.com_users_lain.xml")
     }}
  end

  def get(
        "https://pleroma.soykaf.com/.well-known/webfinger?resource=https://pleroma.soykaf.com/users/lain",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https___pleroma.soykaf.com_users_lain.xml")
     }}
  end

  def get("https://social.heldscal.la/api/statuses/user_timeline/29191.atom", _body, _headers) do
    {:ok,
     %Response{
       status_code: 200,
       body:
         File.read!(
           "test/fixtures/httpoison_mock/https___social.heldscal.la_api_statuses_user_timeline_29191.atom.xml"
         )
     }}
  end

  def get("https://shitposter.club/api/statuses/user_timeline/5381.atom", _body, _headers) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/spc_5381.atom")
     }}
  end

  def get("https://social.heldscal.la/api/statuses/user_timeline/23211.atom", _body, _headers) do
    {:ok,
     %Response{
       status_code: 200,
       body:
         File.read!(
           "test/fixtures/httpoison_mock/https___social.heldscal.la_api_statuses_user_timeline_23211.atom.xml"
         )
     }}
  end

  def get("https://mastodon.social/users/lambadalambda.atom", _body, _headers) do
    {:ok,
     %Response{
       status_code: 200,
       body:
         File.read!(
           "test/fixtures/httpoison_mock/https___mastodon.social_users_lambadalambda.atom"
         )
     }}
  end

  def get(
        "https://social.stopwatchingus-heidelberg.de/api/statuses/user_timeline/18330.atom",
        _body,
        _headers
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/atarifrosch_feed.xml")
     }}
  end

  def get("https://pleroma.soykaf.com/users/lain/feed.atom", _body, _headers) do
    {:ok,
     %Response{
       status_code: 200,
       body:
         File.read!(
           "test/fixtures/httpoison_mock/https___pleroma.soykaf.com_users_lain_feed.atom.xml"
         )
     }}
  end

  def get("https://social.sakamoto.gq/users/eal/feed.atom", _body, _headers) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/sakamoto_eal_feed.atom")
     }}
  end

  def get("http://gs.example.org/index.php/api/statuses/user_timeline/1.atom", _body, _headers) do
    {:ok,
     %Response{
       status_code: 200,
       body:
         File.read!(
           "test/fixtures/httpoison_mock/http__gs.example.org_index.php_api_statuses_user_timeline_1.atom.xml"
         )
     }}
  end

  def get("https://shitposter.club/notice/2827873", _body, _headers) do
    {:ok,
     %Response{
       status_code: 200,
       body:
         File.read!("test/fixtures/httpoison_mock/https___shitposter.club_notice_2827873.html")
     }}
  end

  def get("https://shitposter.club/api/statuses/show/2827873.atom", _body, _headers) do
    {:ok,
     %Response{
       status_code: 200,
       body:
         File.read!(
           "test/fixtures/httpoison_mock/https___shitposter.club_api_statuses_show_2827873.atom.xml"
         )
     }}
  end

  def get("https://shitposter.club/api/statuses/user_timeline/1.atom", _body, _headers) do
    {:ok,
     %Response{
       status_code: 200,
       body:
         File.read!(
           "test/fixtures/httpoison_mock/https___shitposter.club_api_statuses_user_timeline_1.atom.xml"
         )
     }}
  end

  def post(
        "https://social.heldscal.la/main/push/hub",
        {:form, _data},
        "Content-type": "application/x-www-form-urlencoded"
      ) do
    {:ok,
     %Response{
       status_code: 202
     }}
  end

  def get("http://mastodon.example.org/users/admin/statuses/100787282858396771", _, _) do
    {:ok,
     %Response{
       status_code: 200,
       body:
         File.read!(
           "test/fixtures/httpoison_mock/http___mastodon.example.org_users_admin_status_1234.json"
         )
     }}
  end

  def get(
        "https://pawoo.net/.well-known/webfinger",
        [Accept: "application/xrd+xml,application/jrd+json"],
        params: [resource: "https://pawoo.net/users/pekorino"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https___pawoo.net_users_pekorino.xml")
     }}
  end

  def get(
        "https://pawoo.net/.well-known/webfinger?resource=https://pawoo.net/users/pekorino",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https___pawoo.net_users_pekorino.xml")
     }}
  end

  def get("https://pawoo.net/users/pekorino.atom", _, _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https___pawoo.net_users_pekorino.atom")
     }}
  end

  def get(
        "https://mamot.fr/.well-known/webfinger",
        [Accept: "application/xrd+xml,application/jrd+json"],
        params: [resource: "https://mamot.fr/users/Skruyb"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/skruyb@mamot.fr.atom")
     }}
  end

  def get(
        "https://mamot.fr/.well-known/webfinger?resource=https://mamot.fr/users/Skruyb",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/skruyb@mamot.fr.atom")
     }}
  end

  def get(
        "https://social.sakamoto.gq/.well-known/webfinger",
        [Accept: "application/xrd+xml,application/jrd+json"],
        params: [resource: "https://social.sakamoto.gq/users/eal"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/eal_sakamoto.xml")
     }}
  end

  def get(
        "https://social.sakamoto.gq/.well-known/webfinger?resource=https://social.sakamoto.gq/users/eal",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/eal_sakamoto.xml")
     }}
  end

  def get(
        "https://pleroma.soykaf.com/.well-known/webfinger?resource=https://pleroma.soykaf.com/users/shp",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/shp@pleroma.soykaf.com.webfigner")
     }}
  end

  def get(
        "https://squeet.me/xrd/?uri=lain@squeet.me",
        [Accept: "application/xrd+xml,application/jrd+json"],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/lain_squeet.me_webfinger.xml")
     }}
  end

  def get("https://mamot.fr/users/Skruyb.atom", _, _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/https___mamot.fr_users_Skruyb.atom")
     }}
  end

  def get(
        "https://social.sakamoto.gq/objects/0ccc1a2c-66b0-4305-b23a-7f7f2b040056",
        [Accept: "application/atom+xml"],
        _
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/sakamoto.atom")
     }}
  end

  def get("https://pleroma.soykaf.com/users/shp/feed.atom", _, _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/shp@pleroma.soykaf.com.feed")
     }}
  end

  def get("http://social.heldscal.la/.well-known/host-meta", [], follow_redirect: true) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/social.heldscal.la_host_meta")
     }}
  end

  def get("http://status.alpicola.com/.well-known/host-meta", [], follow_redirect: true) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/status.alpicola.com_host_meta")
     }}
  end

  def get("http://macgirvin.com/.well-known/host-meta", [], follow_redirect: true) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/macgirvin.com_host_meta")
     }}
  end

  def get("http://mastodon.social/.well-known/host-meta", [], follow_redirect: true) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/mastodon.social_host_meta")
     }}
  end

  def get("http://shitposter.club/.well-known/host-meta", [], follow_redirect: true) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/shitposter.club_host_meta")
     }}
  end

  def get("http://pleroma.soykaf.com/.well-known/host-meta", [], follow_redirect: true) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/pleroma.soykaf.com_host_meta")
     }}
  end

  def get("http://social.sakamoto.gq/.well-known/host-meta", [], follow_redirect: true) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/social.sakamoto.gq_host_meta")
     }}
  end

  def get("http://gs.example.org/.well-known/host-meta", [], follow_redirect: true) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/gs.example.org_host_meta")
     }}
  end

  def get("http://pawoo.net/.well-known/host-meta", [], follow_redirect: true) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/pawoo.net_host_meta")
     }}
  end

  def get("http://mamot.fr/.well-known/host-meta", [], follow_redirect: true) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/mamot.fr_host_meta")
     }}
  end

  def get("http://mastodon.xyz/.well-known/host-meta", [], follow_redirect: true) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/mastodon.xyz_host_meta")
     }}
  end

  def get("http://social.wxcafe.net/.well-known/host-meta", [], follow_redirect: true) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/social.wxcafe.net_host_meta")
     }}
  end

  def get("http://squeet.me/.well-known/host-meta", [], follow_redirect: true) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/squeet.me_host_meta")
     }}
  end

  def get(
        "http://social.stopwatchingus-heidelberg.de/.well-known/host-meta",
        [],
        follow_redirect: true
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body:
         File.read!("test/fixtures/httpoison_mock/social.stopwatchingus-heidelberg.de_host_meta")
     }}
  end

  def get("http://mastodon.example.org/users/admin", [Accept: "application/activity+json"], _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/admin@mastdon.example.org.json")
     }}
  end

  def get(
        "https://hubzilla.example.org/channel/kaniini",
        [Accept: "application/activity+json"],
        _
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/kaniini@hubzilla.example.org.json")
     }}
  end

  def get("https://masto.quad.moe/users/_HellPie", [Accept: "application/activity+json"], _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/hellpie.json")
     }}
  end

  def get("https://niu.moe/users/rye", [Accept: "application/activity+json"], _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/rye.json")
     }}
  end

  def get("https://n1u.moe/users/rye", [Accept: "application/activity+json"], _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/rye.json")
     }}
  end

  def get(
        "https://mst3k.interlinked.me/users/luciferMysticus",
        [Accept: "application/activity+json"],
        _
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/lucifermysticus.json")
     }}
  end

  def get("https://mstdn.io/users/mayuutann", [Accept: "application/activity+json"], _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/mayumayu.json")
     }}
  end

  def get(
        "http://mastodon.example.org/@admin/99541947525187367",
        [Accept: "application/activity+json"],
        _
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/mastodon-note-object.json")
     }}
  end

  def get(
        "https://mstdn.io/users/mayuutann/statuses/99568293732299394",
        [Accept: "application/activity+json"],
        _
      ) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/mayumayupost.json")
     }}
  end

  def get("https://shitposter.club/notice/7369654", _, _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/7369654.html")
     }}
  end

  def get("https://shitposter.club/api/statuses/show/7369654.atom", _body, _headers) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/7369654.atom")
     }}
  end

  def get("https://baptiste.gelez.xyz/~/PlumeDevelopment/this-month-in-plume-june-2018/", _, _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/baptiste.gelex.xyz-article.json")
     }}
  end

  def get("https://baptiste.gelez.xyz/@/BaptisteGelez", _, _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/baptiste.gelex.xyz-user.json")
     }}
  end

  def get("https://peertube.moe/videos/watch/df5f464b-be8d-46fb-ad81-2d4c2d1630e3", _, _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/peertube.moe-vid.json")
     }}
  end

  def get("https://peertube.moe/accounts/7even", _, _) do
    {:ok,
     %Response{
       status_code: 200,
       body: File.read!("test/fixtures/httpoison_mock/7even.json")
     }}
  end

  def get(url, body, headers) do
    {:error,
     "Not implemented the mock response for get #{inspect(url)}, #{inspect(body)}, #{
       inspect(headers)
     }"}
  end

  def post(url, _body, _headers) do
    {:error, "Not implemented the mock response for post #{inspect(url)}"}
  end

  def post(url, _body, _headers, _options) do
    {:error, "Not implemented the mock response for post #{inspect(url)}"}
  end
end
