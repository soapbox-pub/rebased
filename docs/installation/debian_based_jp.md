# Pleromaの入れ方
## 日本語訳について

この記事は [Installing on Debian based distributions](Installing on Debian based distributions) の日本語訳です。何かがおかしいと思ったら、原文を見てください。

## インストール

このガイドはDebian Stretchを仮定しています。Ubuntu 16.04でも可能です。

### 必要なソフトウェア

- PostgreSQL 9.6+ (postgresql-contrib-9.6 または他のバージョンの PSQL をインストールしてください)
- Elixir 1.5 以上 ([Debianのリポジトリからインストールしないこと！！！ ここからインストールすること！](https://elixir-lang.org/install.html#unix-and-unix-like))。または [asdf](https://github.com/asdf-vm/asdf) を pleroma ユーザーでインストール。
- erlang-dev
- erlang-tools
- erlang-parsetools
- erlang-ssh
- erlang-xmerl (Jessieではバックポートからインストールすること！)
- git
- build-essential
- openssh
- openssl
- nginx prefered (Apacheも動くかもしれませんが、誰もテストしていません！)
- certbot (または何らかのACME Let's encryptクライアント)

### システムを準備する

* まずシステムをアップデートしてください。
```
apt update && apt dist-upgrade
```

* 複数のツールとpostgresqlをインストールします。あとで必要になるので。
```
apt install git build-essential openssl ssh sudo postgresql-9.6 postgresql-contrib-9.6
```
(postgresqlのバージョンは、あなたのディストロにあわせて変えてください。または、バージョン番号がいらないかもしれません。)

### ElixirとErlangをインストールします

* Erlangのリポジトリをダウンロードおよびインストールします。
```
wget -P /tmp/ https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && sudo dpkg -i /tmp/erlang-solutions_1.0_all.deb
```

* ElixirとErlangをインストールします、
```
apt update && apt install elixir erlang-dev erlang-parsetools erlang-xmerl erlang-tools erlang-ssh
```

### Pleroma BE (バックエンド) をインストールします

*  新しいユーザーを作ります。
```
adduser pleroma
``` 
(Give it any password you want, make it STRONG)

*  新しいユーザーをsudoグループに入れます。
```
usermod -aG sudo pleroma
```

*  新しいユーザーに変身し、ホームディレクトリに移動します。
```
su pleroma
cd ~
```

*  Gitリポジトリをクローンします。
```
git clone -b master https://git.pleroma.social/pleroma/pleroma
```

*  新しいディレクトリに移動します。
```
cd pleroma/
```

* Pleromaが依存するパッケージをインストールします。Hexをインストールしてもよいか聞かれたら、yesを入力してください。
```
mix deps.get
```

* コンフィギュレーションを生成します。
```
mix pleroma.instance gen
```
    * rebar3をインストールしてもよいか聞かれたら、yesを入力してください。
    * この処理には時間がかかります。私もよく分かりませんが、何らかのコンパイルが行われているようです。
    * あなたのインスタンスについて、いくつかの質問があります。その回答は `config/generated_config.exs` というコンフィギュレーションファイルに保存されます。

**注意**: メディアプロクシを有効にすると回答して、なおかつ、キャッシュのURLは空欄のままにしている場合は、`generated_config.exs` を編集して、`base_url` で始まる行をコメントアウトまたは削除してください。そして、上にある行の `true` の後にあるコンマを消してください。

* コンフィギュレーションを確認して、もし問題なければ、ファイル名を変更してください。
```
mv config/{generated_config.exs,prod.secret.exs}
```

* これまでのコマンドで、すでに `config/setup_db.psql` というファイルが作られています。このファイルをもとに、データベースを作成します。
```
sudo su postgres -c 'psql -f config/setup_db.psql'
```

* そして、データベースのミグレーションを実行します。
```
MIX_ENV=prod mix ecto.migrate
```

* Pleromaを起動できるようになりました。
```
MIX_ENV=prod mix phx.server
```

### インストールを終わらせる

あなたの新しいインスタンスを世界に向けて公開するには、nginxまたは何らかのウェブサーバー (プロクシ) を使用する必要があります。また、Pleroma のためにシステムサービスファイルを作成する必要があります。

#### Nginx

* まだインストールしていないなら、nginxをインストールします。
```
apt install nginx
```

* SSLをセットアップします。他の方法でもよいですが、ここではcertbotを説明します。
certbotを使うならば、まずそれをインストールします。
```
apt install certbot
```
そしてセットアップします。
```
mkdir -p /var/lib/letsencrypt/.well-known
% certbot certonly --email your@emailaddress --webroot -w /var/lib/letsencrypt/ -d yourdomain
```
もしうまくいかないときは、先にnginxを設定してください。ssl "on" を "off" に変えてから再試行してください。

---

* nginxコンフィギュレーションの例をnginxフォルダーにコピーします。
```
cp /home/pleroma/pleroma/installation/pleroma.nginx /etc/nginx/sites-enabled/pleroma.nginx
```

* nginxを起動する前に、コンフィギュレーションを編集してください。例えば、サーバー名、証明書のパスなどを変更する必要があります。
* nginxを再起動します。
```
systemctl reload nginx.service
```

#### Systemd サービス

* サービスファイルの例をコピーします。
```
cp /home/pleroma/pleroma/installation/pleroma.service /usr/lib/systemd/system/pleroma.service
```

* サービスファイルを変更します。すべてのパスが正しいことを確認してください。また、`[Service]` セクションに以下の行があることを確認してください。
```
Environment="MIX_ENV=prod"
```

* `pleroma.service` を enable および start してください。
```
systemctl enable --now pleroma.service
```

#### モデレーターを作る

新たにユーザーを作ったら、モデレーター権限を与えたいかもしれません。以下のタスクで可能です。
```
mix set_moderator username [true|false]
```

モデレーターはすべてのポストを消すことができます。将来的には他のことも可能になるかもしれません。

#### メディアプロクシを有効にする

`generate_config` でメディアプロクシを有効にしているなら、すでにメディアプロクシが動作しています。あとから設定を変更したいなら、[How to activate mediaproxy](How-to-activate-mediaproxy) を見てください。

#### コンフィギュレーションとカスタマイズ

* [Backup your instance](backup.html)
* [Configuration tips](general-tips-for-customizing-pleroma-fe.html)
* [Hardening your instance](hardening.html)
* [How to activate mediaproxy](howto_mediaproxy.html)
* [Small Pleroma-FE customizations](small_customizations.html)
* [Updating your instance](updating.html)

## 質問ある？

インストールについて質問がある、もしくは、うまくいかないときは、以下のところで質問できます。

* [#pleroma:matrix.org](https://matrix.heldscal.la/#/room/#freenode_#pleroma:matrix.org)
* **Freenode** の **#pleroma** IRCチャンネル
