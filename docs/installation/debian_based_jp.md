# Pleromaの入れ方
## 日本語訳について

この記事は [Installing on Debian based distributions](Installing on Debian based distributions) の日本語訳です。何かがおかしいと思ったら、原文を見てください。

## インストール

このガイドはDebian Stretchを利用することを想定しています。Ubuntu 16.04や18.04でもおそらく動作します。また、ユーザはrootもしくはsudoにより管理者権限を持っていることを前提とします。もし、以下の操作をrootユーザで行う場合は、 `sudo` を無視してください。ただし、`sudo -Hu pleroma` のようにユーザを指定している場合には `su <username> -s $SHELL -c 'command'` を代わりに使ってください。

### 必要なソフトウェア

- PostgreSQL 9.6以上 (Ubuntu16.04では9.5しか提供されていないので，[](https://www.postgresql.org/download/linux/ubuntu/)こちらから新しいバージョンを入手してください)
- `postgresql-contrib` 9.6以上 (同上)
- Elixir 1.8 以上 ([Debianのリポジトリからインストールしないこと！！！ ここからインストールすること！](https://elixir-lang.org/install.html#unix-and-unix-like)。または [asdf](https://github.com/asdf-vm/asdf) をpleromaユーザーでインストールしてください)
- `erlang-dev`
- `erlang-nox`
- `git`
- `build-essential`

#### このガイドで利用している追加パッケージ

- `nginx` (おすすめです。他のリバースプロキシを使う場合は、参考となる設定をこのリポジトリから探してください)
- `certbot` (または何らかのLet's Encrypt向けACMEクライアント)

### システムを準備する

* まずシステムをアップデートしてください。
```
sudo apt update
sudo apt full-upgrade
```

* 上記に挙げたパッケージをインストールしておきます。
```
sudo apt install git build-essential postgresql postgresql-contrib
```


### ElixirとErlangをインストールします

* Erlangのリポジトリをダウンロードおよびインストールします。
```
wget -P /tmp/ https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb
sudo dpkg -i /tmp/erlang-solutions_1.0_all.deb
```

* ElixirとErlangをインストールします、
```
sudo apt update
sudo apt install elixir erlang-dev erlang-nox
```

### Pleroma BE (バックエンド) をインストールします

*  Pleroma用に新しいユーザーを作ります。

```
sudo useradd -r -s /bin/false -m -d /var/lib/pleroma -U pleroma
```

**注意**: Pleromaユーザとして単発のコマンドを実行したい場合はは、`sudo -Hu pleroma command` を使ってください。シェルを使いたい場合は `sudo -Hu pleroma $SHELL`です。もし `sudo` を使わない場合は、rootユーザで `su -l pleroma -s $SHELL -c 'command'` とすることでコマンドを、`su -l pleroma -s $SHELL` とすることでシェルを開始できます。

*  Gitリポジトリをクローンします。
```
sudo mkdir -p /opt/pleroma
sudo chown -R pleroma:pleroma /opt/pleroma
sudo -Hu pleroma git clone -b stable https://git.pleroma.social/pleroma/pleroma /opt/pleroma
```

*  新しいディレクトリに移動します。
```
cd /opt/pleroma
```

* Pleromaが依存するパッケージをインストールします。Hexをインストールしてもよいか聞かれたら、yesを入力してください。
```
sudo -Hu pleroma mix deps.get
```

* コンフィギュレーションを生成します。
```
sudo -Hu pleroma mix pleroma.instance gen
```
    * rebar3をインストールしてもよいか聞かれたら、yesを入力してください。
    * このときにpleromaの一部がコンパイルされるため、この処理には時間がかかります。
    * あなたのインスタンスについて、いくつかの質問されます。この質問により `config/generated_config.exs` という設定ファイルが生成されます。


* コンフィギュレーションを確認して、もし問題なければ、ファイル名を変更してください。
```
mv config/{generated_config.exs,prod.secret.exs}
```

* 先程のコマンドで、すでに `config/setup_db.psql` というファイルが作られています。このファイルをもとに、データベースを作成します。
```
sudo -Hu pleroma mix pleroma.instance gen
```

* そして、データベースのマイグレーションを実行します。
```
sudo -Hu pleroma MIX_ENV=prod mix ecto.migrate
```

* これでPleromaを起動できるようになりました。
```
sudo -Hu pleroma MIX_ENV=prod mix phx.server
```

### インストールの最終段階

あなたの新しいインスタンスを世界に向けて公開するには、nginx等のWebサーバやプロキシサーバをPleromaの前段に使用する必要があります。また、Pleroma のためにシステムサービスファイルを作成する必要があります。

#### Nginx

* まだインストールしていないなら、nginxをインストールします。
```
sudo apt install nginx
```

* SSLをセットアップします。他の方法でもよいですが、ここではcertbotを説明します。
certbotを使うならば、まずそれをインストールします。
```
sudo apt install certbot
```
そしてセットアップします。
```
sudo mkdir -p /var/lib/letsencrypt/
sudo certbot certonly --email <your@emailaddress> -d <yourdomain> --standalone
```
もしうまくいかないときは、nginxが正しく動いていない可能性があります。先にnginxを設定してください。ssl "on" を "off" に変えてから再試行してください。

---

* nginxの設定ファイルサンプルをnginxフォルダーにコピーします。
```
sudo cp /opt/pleroma/installation/pleroma.nginx /etc/nginx/sites-available/pleroma.nginx
sudo ln -s /etc/nginx/sites-available/pleroma.nginx /etc/nginx/sites-enabled/pleroma.nginx
```

* nginxを起動する前に、設定ファイルを編集してください。例えば、サーバー名、証明書のパスなどを変更する必要があります。
* nginxを再起動します。
```
sudo systemctl enable --now nginx.service
```

もし証明書を更新する必要が出てきた場合には、nginxの関連するlocationブロックのコメントアウトを外し、以下のコマンドを動かします。

```
sudo certbot certonly --email <your@emailaddress> -d <yourdomain> --webroot -w /var/lib/letsencrypt/
```

#### 他のWebサーバやプロキシ
これに関してはサンプルが `/opt/pleroma/installation/` にあるので、探してみてください。

#### Systemd サービス

* サービスファイルのサンプルをコピーします。
```
sudo cp /opt/pleroma/installation/pleroma.service /etc/systemd/system/pleroma.service
```

* サービスファイルを変更します。すべてのパスが正しいことを確認してください
* サービスを有効化し `pleroma.service` を開始してください
```
sudo systemctl enable --now pleroma.service
```

#### 初期ユーザの作成

新たにインスタンスを作成したら、以下のコマンドにより管理者権限を持った初期ユーザを作成できます。

```
sudo -Hu pleroma MIX_ENV=prod mix pleroma.user new <username> <your@emailaddress> --admin
```

#### その他の設定とカスタマイズ

* [Backup your instance](../administration/backup.md)
* [Hardening your instance](../configuration/hardening.md)
* [How to activate mediaproxy](../configuration/howto_mediaproxy.md)
* [Updating your instance](../administration/updating.md)

## 質問ある？

インストールについて質問がある、もしくは、うまくいかないときは、以下のところで質問できます。

* [#pleroma:matrix.org](https://matrix.heldscal.la/#/room/#freenode_#pleroma:matrix.org)
* **Freenode** の **#pleroma** IRCチャンネル
