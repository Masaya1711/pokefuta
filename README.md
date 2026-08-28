# ポケふた収集アプリ

ポケモン公式サイト「ポケモンローカルActs」(https://local.pokemon.jp/manhole/) の設置済みポケふた情報を追跡し、GPSチェックイン・写真記録・周辺おすすめスポット投稿ができるiOSアプリ。

開発の背景・設計判断の詳細は `C:\Users\admin\.claude\plans\eventual-jingling-mccarthy.md` の計画書を参照。

## 構成

```
backend/scraper/  ポケふた一覧を取得するNode.jsスクリプト(オンデマンド実行、常駐サーバーなし)
data/manholes.json  スクレイパーの出力。アプリはこれをHTTPで取得する
ios/               SwiftUI製iOSアプリ (XcodeGenでプロジェクト生成)
codemagic.yaml     クラウドMacでのビルド・TestFlight配布設定
```

**費用は Apple Developer Program の $99/年のみ**。バックエンドはFirebase/Google Cloud等の外部サービスを一切使わず、Apple純正のCloudKit(無料)と、GitHub上の静的JSONファイルだけで完結する。

- 地図: MapKit(Apple純正、無料、APIキー不要)
- チェックイン・写真・おすすめスポット投稿・ログイン: CloudKit(Apple純正、無料枠が非常に大きく個人〜小規模友人利用なら実質無料)。ログインはiCloudアカウントに自動的に紐づくため、メール/パスワードのサインアップ画面は無い
- ポケふた一覧データ: 自動更新ではなく、**依頼を受けたタイミングでスクレイパーを手動実行し、`data/manholes.json`を更新してpush**する運用(頻繁に変わるものではないため)

この構成はWindows環境のみで完結するよう設計している。iOSアプリのビルド・コード署名・TestFlightアップロードはクラウド上のMac(Codemagic)で行うため、ローカルにXcode/macOSは不要。

---

## 1. GitHubリポジトリの準備

このリポジトリには秘密情報(APIキー等)が一切含まれないため、**公開(public)リポジトリ**として作成する。`data/manholes.json`を`raw.githubusercontent.com`経由でアプリから直接(認証なしで)取得するため。

1. GitHubで新規リポジトリを作成(public)
2. このプロジェクトフォルダの内容をpush
3. `ios/Sources/Services/AppConfig.swift`の`manholeCatalogURL`を、実際のユーザー名/リポジトリ名に書き換える

```powershell
cd "C:\Users\admin\Works\100_claude code\pokehuta"
git remote add origin https://github.com/<あなたのユーザー名>/<リポジトリ名>.git
git push -u origin master
```

## 2. ポケふた一覧データの更新(オンデマンド)

Firebaseのような自動日次実行はしない。新しいポケふたが公式サイトに追加された、などのタイミングで、Claudeに「ポケふたデータを更新して」と依頼すると、以下が実行される。

```powershell
cd backend\scraper
npm install
npm run sync
```

`data/manholes.json`が更新されるので、差分を確認してcommit・pushする。2026年8月時点で482件、全件取得に数分程度かかる(サイトへの負荷を抑えるため意図的に間隔を空けている)。

## 3. CloudKitのセットアップ(Apple Developer Portal)

1. [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list)でApp ID(`com.kmtsjym.pokehuta`)を作成し、「iCloud」機能(Capability)を有効化。コンテナは`iCloud.com.kmtsjym.pokehuta`という名前で新規作成する(`ios/project.yml`の`entitlements`と一致させること)
2. [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)で対象コンテナを開き、以下のレコードタイプをPublicデータベースに作成する:
   - `UserProfile`: `displayName`(String), `backgroundCheckInEnabled`(Int64)
   - `Checkin`: `manholeId`(String, インデックス可), `ownerRecordName`(String, インデックス可), `method`(String), `distanceMeters`(Double)
   - `ManholePhoto`: `manholeId`(String, インデックス可), `ownerRecordName`(String), `asset`(Asset)
   - `Spot`: `manholeId`(String, インデックス可), `ownerRecordName`(String), `name`(String), `category`(String), `rating`(Int64), `comment`(String)
3. 各レコードタイプで`manholeId`・`ownerRecordName`にQueryableインデックスを設定する(アプリ側のCKQueryで絞り込み検索するため必須)
4. CloudKitの「Security Roles」で、Publicデータベースの`World`ロールに対して該当レコードタイプの Read/Write を許可する(友人同士がお互いの投稿を見られるようにするため)

## 4. iOSアプリのビルド(Codemagic)

1. [Codemagic](https://codemagic.io/)にGitHubアカウントで登録し、リポジトリを連携
2. Apple Developer Programに登録(年$99)し、App Store Connectで以下を準備:
   - App Store Connect API Key を発行し、Codemagicの「Team integrations」→「Apple Developer Portal」に登録(連携名を `pokehuta_asc_api_key` にすると `codemagic.yaml` そのまま使える)
   - App Store Connectにアプリ登録(バンドルID `com.kmtsjym.pokehuta`)し、発行されたApple ID(数字)を `codemagic.yaml` の `APP_STORE_APPLE_ID` に設定
   - 外部テスターグループ(例: "Friends")を作成し、`codemagic.yaml` の `beta_groups` に反映
3. Codemagicでワークフロー `ios-testflight` を実行するとビルド→自動コード署名→TestFlightアップロードまで自動で行われる
4. 友人をApp Store Connectから外部テスターとして招待(メールまたは公開リンク)。**初回ビルドのみAppleの簡易審査(Beta App Review、通常1〜2日程度)が入る**

以降の開発サイクル: Windows上でSwiftファイルや `ios/project.yml` を編集 → git push → Codemagicが自動ビルド → TestFlightで実機確認。

## 留意事項

- `local.pokemon.jp` は非公式なスクレイピング対象。個人・友人利用の範囲に留め、オンデマンド実行のみに留めること。
- iOSのバックグラウンドジオフェンス監視は同時20件までの制約があるため、現在地に応じて動的に監視対象を差し替える設計にしている(`ios/Sources/Services/LocationManager.swift`)。
- 写真投稿の事前自動モデレーションは行っていない(信頼できる友人のみの利用が前提)。
- リポジトリを公開(public)にするため、個人情報や連絡先などをコミットしないよう注意する。
