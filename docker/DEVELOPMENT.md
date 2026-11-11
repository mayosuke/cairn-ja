# コンテナでの開発

Rancher Desktopを起動し、コンテナエンジンを **dockerd (moby)** に設定する。
`~/.rd/bin` をPATHに追加し、Dockerの接続先を確認する：

```sh
export PATH="$HOME/.rd/bin:$PATH"
docker context use rancher-desktop
docker info
```

このリポジトリのルートで起動する：

```sh
docker compose -p cairn-ja up --build -d
```

以下のコマンドは `rancher-desktop` コンテキストを使う前提。
通常のDocker Engineでも、接続先をその環境に合わせれば同じCompose設定を利用できる。
初回ビルドにはRubyイメージとGemのダウンロードのためインターネット接続が必要。
ブラウザで <http://127.0.0.1:4000/> を開く。

Ruby 3.3.12 / Debian 13のベースイメージはダイジェストで固定し、
Bundlerは4.0.14、GemはGemfile.lockのバージョンを使用する。
現在の作業環境はLinux ARM64。別のCPUではベースイメージがそのCPU向けに選択される。
Gemはイメージに含めるので、既存の `cairn-en-dev-gems` ボリュームや `tmp/` の設定は不要。
ソースは `/source` にマウントし、生成物とSassキャッシュはコンテナ内の `/preview` に置く。
Markdownなどを保存すると全体を自動ビルドする。完了後、ブラウザを手動でリロードする。
既存環境に合わせてLiveReloadのフラグとポートも保持しているが、自動更新は未確認。

起動時に `docker/entrypoint.sh` が `CAIRN_PORT`（既定値4000）を検証し、
公開URLを `/opt/cairn/runtime.yml` に生成する。有効な値は1〜65535の整数。
Jekyllは `_config.yml`、`/opt/cairn/jekyll-dev.yml`、生成した設定の順に読み込み、
絶対URLやサイトマップにも公開ポートを反映する。コンテナ内の待受ポートは4000のまま。
`JEKYLL_ENV=docker` により、開発モードでJekyllがURLを待受アドレスで上書きする挙動を避ける。

## 別ポートでの起動

ルートに `.env` を作成して未使用のポートを指定する。
以下は4004・35730番が空いている場合の例：

```dotenv
CAIRN_PORT=4004
CAIRN_LIVERELOAD_PORT=35730
```

```sh
docker compose -p cairn-ja --env-file .env up --build -d
```

この場合は <http://127.0.0.1:4004/> を開く。生成されるサイトの公開URLも自動で一致する。
`CAIRN_LIVERELOAD_PORT` はホスト側の公開ポートだけを変更し、
コンテナ内のLiveReload待受は35729のまま。ブラウザ側の接続先が自動で追従することは未確認。

`.env` はGit管理対象外。Docker Composeは通常ルートの `.env` を自動で読むが、
上記のように `--env-file` で明示してもよい。通常の4000番に戻すときは
`.env` のポート指定を削除し、`docker compose -p cairn-ja up -d` で再作成する。
`restart` だけではポートや環境変数の変更は反映されない。

同じソースを別コンテナとして並行起動する場合は、ポートに加えてプロジェクト名も
`-p cairn-ja-preview` などに変え、以後の操作でも同じ名前を指定する。

## 日常の操作

```sh
# ログ（Ctrl-Cでログ表示だけを終了）
docker compose -p cairn-ja logs -f dev

# 停止 / 再開
docker compose -p cairn-ja stop
docker compose -p cairn-ja start

# _config.ymlを変更した後
docker compose -p cairn-ja restart dev

# Dockerfile、docker/entrypoint.sh、docker/jekyll-dev.yml、Gemfile.lockを変更した後
docker compose -p cairn-ja up --build -d

# 稼働中のコンテナで単発ビルド（起動時に生成した公開URL設定も使用）
docker compose -p cairn-ja exec dev bundle _4.0.14_ exec jekyll build --config _config.yml,/opt/cairn/jekyll-dev.yml,/opt/cairn/runtime.yml --destination /preview/_build-check
```

Gemfileを変更する場合はGemfile.lockも更新してから再ビルドする。
`BUNDLE_FROZEN=true` により、ロックファイルと一致しない依存関係ではビルドが失敗する。
ソースコードはホストに残る。コンテナを再作成すると `/preview` は再生成される。
単発ビルドは配信中の出力と競合しないよう、別の出力先を指定している。

## 英語版上流のプレビュー（4100番）

このComposeプロジェクトとは独立した `yochaigal/cairn` のプレビュー。
ソースは隣の `../cairn-upstream-preview`、起動設定は
`../cairn-upstream-preview-support` にある。ソースは読み取り専用でマウントする。

```sh
# 初回作成、または既存コンテナの起動（リポジトリのルートで実行）
sh ../cairn-upstream-preview-support/docker-start.sh

docker logs -f cairn-upstream-main-preview-20261109
docker stop cairn-upstream-main-preview-20261109
docker start cairn-upstream-main-preview-20261109
```

ブラウザで <http://127.0.0.1:4100/> を開く。
このプレビューは変更監視を無効にしているため、ソース変更後は同コンテナを再起動する。
取得済みの `main` を使い、起動時に自動で最新版へ更新することはない。

## containerdからの移行

containerdとdockerdではコンテナ・イメージ・ボリュームの管理が別になる。
エンジンを切り替えても旧コンテナは引き継がれないため、dockerd側で再作成する。
旧環境の `cairn-en-dev-gems` は不要で、このCompose環境ではGemをイメージ内に持つ。
4100番のプレビューにはdockerd側の専用Gem・生成物ボリュームを使用する。

Docker自身も内部でcontainerdを使用するため、containerdという名前だけで
プロセス・ソケット・ストレージを削除しないこと。旧環境の削除は管理先と参照関係を確認して行う。
`docker system prune` やボリュームの一括削除は、他プロジェクトへ影響するため使わない。

2026-11-11、停止時間の了承を得て一時的にcontainerdへ戻し、旧Cairnコンテナ5個、
参照のなくなったGem・生成物ボリューム3個、`cairn-ja_default` ネットワーク、
`cairn-ja-dev:latest` と `cairn-url-verify-1794200365-dev:latest` のイメージを削除した。
共有の可能性があるRubyイメージとビルドキャッシュは残している。
旧ストレージ全体を削除したわけではない。

エンジン切り替え時は4000・4100番だけでなく他プロジェクトのサービスも停止するため、
事前に停止時間を調整する。削除後はdockerdへ戻し、4000・4100・8000番のHTTP 200応答を確認した。

## 動作確認

2026-10-13、Rancher Desktop / Linux ARM64で、既存のGemボリュームを使わずに
イメージをビルドし、Composeで起動できることを確認した。
Ruby・Bundlerのバージョン、HTTP 200応答、ホストで保存したMarkdownの自動反映、
開発用ファイルがプレビューに出力されないことを確認済み。
この記録は旧containerd環境での確認。Linux AMD64での実行は未検証。

2026-11-09、公開ポートと生成URLの同期を追加し、Rancher Desktop / Linux ARM64で再検証した。
既存の4000・4002番コンテナを維持したまま、独立した検証環境を4100番で起動し、
以下を確認した（検証用コンテナは確認後に削除済み）：

- Dockerfileのビルド成功、ホームページ・CSS・JavaScript・サイトマップのHTTP 200応答。
- `/opt/cairn/runtime.yml` とサイトマップ全354件のURLが4100番に一致。
- 分離したソースへのMarkdown追加による自動再生成。
- 既定ポート4000の設定生成と、不正なポート指定での起動拒否。
- LiveReloadのJavaScript取得とWebSocket接続。ブラウザの自動更新は未確認。

4100番の英語版上流プレビューは、この検証用コンテナとは別のもの。

2026-11-11、Rancher Desktop / dockerd 29.5.3 / Linux ARM64で両サイトを再作成した。

- 4000番：このリポジトリのComposeプロジェクト `cairn-ja`。
- 4100番：英語版上流の取得済みコミット `69a2db314dced8657bfb435b69372ad73bca59bb`。
- 両ホームページとCSS・JavaScript計14件のHTTP 200応答を確認。
- canonical URLとサイトマップ（4000番354件、4100番355件）がそれぞれの公開ポートに一致。
- 両サイトで固定依存関係のチェックが成功。既存の8000番サービスへの影響なし。

dockerd移行後のファイル変更時の自動再生成と、ブラウザのLiveReload自動更新は未検証。
