# コンテナでの開発

Rancher Desktopを起動し、コンテナエンジンをcontainerdに設定する。
このリポジトリのルートで次の1コマンドを実行する：

```sh
~/.rd/bin/nerdctl compose up --build -d
```

Dockerを使う場合は `docker compose up --build -d` で起動できる。
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

## 既存コンテナとの切り替え

現在の `cairn-en-dev` が4000・35729番ポートを使用している場合は、先に停止する：

```sh
~/.rd/bin/nerdctl stop cairn-en-dev
~/.rd/bin/nerdctl compose up --build -d
```

既存コンテナを止めずに並行して試す場合は、ルートに `.env` を作成して
未使用のポートを指定する。以下は4004・35730番が空いている場合の例：

```dotenv
CAIRN_PORT=4004
CAIRN_LIVERELOAD_PORT=35730
```

```sh
~/.rd/bin/nerdctl compose --env-file .env up --build -d
```

この場合は <http://127.0.0.1:4004/> を開く。生成されるサイトの公開URLも自動で一致する。
`CAIRN_LIVERELOAD_PORT` はホスト側の公開ポートだけを変更し、
コンテナ内のLiveReload待受は35729のまま。ブラウザ側の接続先が自動で追従することは未確認。

`.env` はGit管理対象外。この環境のRancher Desktopのnerdctlではシェルの環境変数が
Composeに渡らなかったため、明示的に `--env-file .env` を指定して検証した。
以下の日常操作でも、ポートを変更している場合は `compose` の直後に
`--env-file .env` を付ける。通常の4000番に戻すときは `.env` のポート指定を削除し、
`compose up -d` で再作成する。`restart` だけではポートや環境変数の変更は反映されない。

なお、別途起動した英語版上流の4100番コンテナは、このComposeプロジェクトとは独立している。

## 日常の操作

```sh
# ログ（Ctrl-Cでログ表示だけを終了）
~/.rd/bin/nerdctl compose logs -f dev

# 停止 / 再開
~/.rd/bin/nerdctl compose stop
~/.rd/bin/nerdctl compose start

# _config.ymlを変更した後
~/.rd/bin/nerdctl compose restart dev

# Dockerfile、docker/entrypoint.sh、docker/jekyll-dev.yml、Gemfile.lockを変更した後
~/.rd/bin/nerdctl compose up --build -d

# 稼働中のコンテナで単発ビルド（起動時に生成した公開URL設定も使用）
~/.rd/bin/nerdctl compose exec dev bundle _4.0.14_ exec jekyll build --config _config.yml,/opt/cairn/jekyll-dev.yml,/opt/cairn/runtime.yml
```

Gemfileを変更する場合はGemfile.lockも更新してから再ビルドする。
`BUNDLE_FROZEN=true` により、ロックファイルと一致しない依存関係ではビルドが失敗する。
ソースコードはホストに残る。コンテナを再作成すると `/preview` は再生成される。

## 動作確認

2026-10-13、Rancher Desktop / Linux ARM64で、既存のGemボリュームを使わずに
イメージをビルドし、Composeで起動できることを確認した。
Ruby・Bundlerのバージョン、HTTP 200応答、ホストで保存したMarkdownの自動反映、
開発用ファイルがプレビューに出力されないことを確認済み。
Docker EngineとLinux AMD64での実行は未検証。

2026-11-09、公開ポートと生成URLの同期を追加し、Rancher Desktop / Linux ARM64で再検証した。
既存の4000・4002番コンテナを維持したまま、独立した検証環境を4100番で起動し、
以下を確認した（検証用コンテナは確認後に削除済み）：

- Dockerfileのビルド成功、ホームページ・CSS・JavaScript・サイトマップのHTTP 200応答。
- `/opt/cairn/runtime.yml` とサイトマップ全354件のURLが4100番に一致。
- 分離したソースへのMarkdown追加による自動再生成。
- 既定ポート4000の設定生成と、不正なポート指定での起動拒否。
- LiveReloadのJavaScript取得とWebSocket接続。ブラウザの自動更新は未確認。

現在4100番で稼働している英語版上流プレビューは、この検証用コンテナとは別のもの。
