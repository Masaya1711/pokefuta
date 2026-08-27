# ポケふた収集アプリ

ポケモン公式サイト「ポケモンローカルActs」(https://local.pokemon.jp/manhole/) の設置済みポケふた情報を毎日追跡し、GPSチェックイン・写真記録・周辺おすすめスポット投稿ができるiOSアプリ。

開発の背景・設計判断の詳細は `C:\Users\admin\.claude\plans\eventual-jingling-mccarthy.md` の計画書を参照。

## 構成

```
backend/   Firebase (Firestore / Cloud Functions / Storage / Auth)
ios/       SwiftUI製iOSアプリ (XcodeGenでプロジェクト生成)
codemagic.yaml  クラウドMacでのビルド・TestFlight配布設定
```

この構成はWindows環境のみで完結するよう設計している。iOSアプリのビルド・コード署名・TestFlightアップロードはクラウド上のMac(Codemagic)で行うため、ローカルにXcode/macOSは不要。

---

## 0. 課金なし・ローカルだけで試す(Firebaseエミュレータ)

実際のFirebaseプロジェクトを作らなくても、Firestore/Storage/Cloud Functionsは**エミュレータ**でPC上だけで動かせる。Googleアカウントへのログインも課金も一切不要。

```powershell
cd backend
npm install --ignore-scripts   # firebase-toolsを取得(初回のみ)
cd functions
npm install --ignore-scripts
npm run build
cd ..
npm run emulators              # --project demo-pokehuta で起動(デモ用の架空プロジェクトID)
```

ブラウザで http://127.0.0.1:4000 を開くとEmulator UIからFirestore/Storageの中身を確認できる。この状態で `syncManholesManual` 相当のロジックを動かして実際に`local.pokemon.jp`から取得したデータがFirestoreに入ることを確認済み(2026年8月時点で482件のポケふたを実際に検出)。

**注意**: Firestore/Storageエミュレータの実体はJavaで動いているため、Java 21以上が必要(`java -version`で確認)。写真モデレーション(`moderatePhoto`)が呼び出すCloud Vision APIは実際のGoogle Cloud課金を伴う外部サービスのため、エミュレータでは動作確認できない(後述の本番デプロイ時に確認)。

ここまでは無料で完結する。本番相当の動作(毎日自動実行・実際のiPhoneアプリからのアクセス)を試すには、以下の手順で実際のFirebaseプロジェクトが必要になる。

## 1. Firebaseプロジェクトのセットアップ

1. [Firebaseコンソール](https://console.firebase.google.com/)で新規プロジェクトを作成
2. **Blazeプラン(従量課金)にアップグレード**(Cloud Schedulerと外部サイトへのHTTPリクエストにはBlazeプランが必須。この規模なら実費は月数百円程度の見込み)
3. 以下を有効化:
   - Firestore Database(本番モードで開始)
   - Storage
   - Authentication → Email/Password プロバイダを有効化
   - Cloud Vision API(Google Cloudコンソール側で有効化。写真の自動モデレーションに使用)
4. Firebaseコンソール → プロジェクトの設定 → iOSアプリを追加(バンドルID: `com.kmtsjym.pokehuta`)し、`GoogleService-Info.plist` をダウンロードして `ios/GoogleService-Info.plist` に配置する(このファイルはAPIキーを含むが機密情報ではなく、Firebaseの公式ドキュメント上もリポジトリへのコミットが前提とされている。実際のアクセス制御は`firestore.rules`/`storage.rules`で行う)
5. `backend/.firebaserc` の `REPLACE_WITH_YOUR_FIREBASE_PROJECT_ID` を実際のプロジェクトIDに書き換える

## 2. バックエンド(Cloud Functions)のセットアップ

Windows上でNode.js(20系推奨)をインストール後:

```powershell
npm install -g firebase-tools
cd backend
firebase login
cd functions
npm install
npm run build
```

### ローカルエミュレータでの動作確認

```powershell
cd backend
firebase emulators:start --only functions,firestore,storage,auth
```

Emulator UI (http://localhost:4000) から `syncManholesManual` をFirestoreのテストユーザーで呼び出すか、下記のデプロイ後の手順で本番に対して実行して動作確認する。

### デプロイ

```powershell
cd backend
firebase deploy --only functions,firestore:rules,storage:rules
```

### 初回データ投入

デプロイ後、認証済みユーザーとして `syncManholesManual` (Callable Function) を1回呼び出すと、サイト上の全ポケふた(2026年8月時点で480件超)がFirestoreに投入される。以降は `syncManholesDaily` が毎日JST4時に新着分のみを自動追加する。呼び出しにはFirebase CLIや簡単なNode.jsスクリプト、あるいはアプリの管理者用デバッグボタンなどを用意して実行する。

## 3. iOSアプリのビルド(Codemagic)

1. このリポジトリをGitHub(プライベートリポジトリ推奨)にpush
2. [Codemagic](https://codemagic.io/)にGitHubアカウントで登録し、このリポジトリを連携
3. Apple Developer Programに登録し、App Store Connectで以下を準備:
   - App Store Connect API Key を発行し、Codemagicの「Team integrations」→「Apple Developer Portal」に登録(連携名を `pokehuta_asc_api_key` にすると `codemagic.yaml` そのまま使える)
   - App Store Connectにアプリ登録(バンドルID `com.kmtsjym.pokehuta`)し、発行されたApple ID(数字)を `codemagic.yaml` の `APP_STORE_APPLE_ID` に設定
   - 内部テスターグループ(例: "Internal Testers")を作成し、`codemagic.yaml` の `beta_groups` に反映
4. Codemagicでワークフロー `ios-testflight` を実行するとビルド→自動コード署名→TestFlightアップロードまで自動で行われる
5. 友人はTestFlightアプリ経由でインストール可能になる(招待リンクをApp Store Connectから発行)

以降の開発サイクル: Windows上でSwiftファイルや `ios/project.yml` を編集 → git push → Codemagicが自動ビルド → TestFlightで実機確認。

## 留意事項

- `local.pokemon.jp` は非公式なスクレイピング対象。個人・友人利用の範囲に留め、日次1回程度の低頻度アクセスに留めること。
- iOSのバックグラウンドジオフェンス監視は同時20件までの制約があるため、現在地に応じて動的に監視対象を差し替える設計にしている(`ios/Sources/Services/LocationManager.swift`)。
