# Pleroman asennus OpenBSD:llä

Tarvitset:
* Oman domainin
* OpenBSD 6.3 -serverin
* Auttavan ymmärryksen unix-järjestelmistä

Komennot, joiden edessä on '#', tulee ajaa käyttäjänä `root`. Tämä on
suositeltavaa tehdä komennon `doas` avulla, katso `doas (1)` ja `doas.conf (5)`.
Tästä eteenpäin oletuksena on, että domain "esimerkki.com" osoittaa
serverin IP-osoitteeseen.

Jos asennuksen kanssa on ongelmia, IRC-kanava #pleroma Freenodessa tai
Matrix-kanava #freenode_#pleroma:matrix.org ovat hyviä paikkoja löytää apua
(englanniksi), `/msg eal kukkuu` jos haluat välttämättä puhua härmää.

Asenna tarvittava ohjelmisto:

`# pkg_add git elixir gmake postgresql-server-10.3 postgresql-contrib-10.3`

Luo postgresql-tietokanta:

`# su - _postgresql`

`$ mkdir /var/postgresql/data`

`$ initdb -D /var/postgresql/data -E UTF8`

`$ createdb`

Käynnistä tietokanta ja aseta se käynnistymään automaattisesti.

`# rcctl start postgresql`

`# rcctl enable postgresql`

Luo käyttäjä pleromaa varten (kysyy muutaman kysymyksen):

`# adduser pleroma`

Vaihda pleroma-käyttäjään ja mene kotihakemistoosi:

`# su - pleroma`

Lataa pleroman lähdekoodi:

`$ git clone -b stable https://git.pleroma.social/pleroma/pleroma.git`

`$ cd pleroma`

Asenna tarvittavat elixir-kirjastot:

`$ mix deps.get`

`$ mix deps.compile`

Luo tarvittava konfiguraatio:

`$ mix generate_config`

`$ cp config/generated_config.exs config/prod.secret.exs`

Aja luodut tietokantakomennot:

`# su _postgres -c 'psql -f config/setup_db.psql'`

`$ MIX_ENV=prod mix ecto.migrate`

Käynnistä pleroma-prosessi:

`$ MIX_ENV=prod mix compile`

`$ MIX_ENV=prod mix phx.server`

Tässä vaiheessa on hyvä tarkistaa että asetukset ovat oikein. Avaa selaimella,
curlilla tai vastaavalla työkalulla `esimerkki.com:4000/api/v1/instance` ja katso
että kohta "uri" on "https://esimerkki.com".

Huom! Muista varmistaa että muuttuja MIX_ENV on "prod" mix-komentoja ajaessasi.
Mix lukee oikean konfiguraatiotiedoston sen mukaisesti.

Ohessa enimmäkseen toimivaksi todettu rc.d-skripti pleroman käynnistämiseen.
Kirjoita se tiedostoon /etc/rc.d/pleroma. Tämän jälkeen aja
`# chmod +x /etc/rc.d/pleroma`, ja voit käynnistää pleroman komennolla
`# /etc/rc.d/pleroma start`.

```
#!/bin/ksh
#/etc/rc.d/pleroma

daemon="cd /home/pleroma/pleroma;MIX_ENV=prod /usr/local/bin/elixir"
daemon_flags="--detached /usr/local/bin/mix phx.server"
daemon_user="pleroma"
rc_reload="NO"
rc_bg="YES"

pexp="beam"

. /etc/rc.d/rc.subr

rc_cmd $1
```

Tämän jälkeen tarvitset enää HTTP-serverin välittämään kutsut pleroma-prosessille.
Tiedostosta `install/pleroma.nginx` löytyy esimerkkikonfiguraatio, ja TLS-sertifikaatit
saat ilmaiseksi esimerkiksi [letsencryptiltä](https://certbot.eff.org/lets-encrypt/opbsd-nginx.html).
Nginx asentuu yksinkertaisesti komennolla `# pkg_add nginx`.

Kun olet valmis, avaa https://esimerkki.com selaimessasi. Luo käyttäjä ja seuraa kiinnostavia
tyyppejä muilla palvelimilla!
