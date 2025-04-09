import SwiftUI
import WebKit

// WebView: canGoBack／canGoForward／pageTitle／pageURL をバインディング
struct WebView: NSViewRepresentable {
    let url: URL
    @Binding var pageTitle: String
    @Binding var pageURL: String
    @Binding var webView: WKWebView?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool

    func makeNSView(context: Context) -> WKWebView {
        let wv = WKWebView(frame: .zero)
        wv.navigationDelegate = context.coordinator

        // KVO のセットアップ
        context.coordinator.observe(webView: wv)

        // 最初のロード
        wv.load(URLRequest(url: url))

        // 背景を黒に
        wv.setValue(false, forKey: "drawsBackground")
        wv.wantsLayer = true
        wv.layer?.backgroundColor = NSColor.black.cgColor

        // SwiftUI 側にも参照を渡す
        DispatchQueue.main.async {
            self.webView = wv
            self.canGoBack    = wv.canGoBack
            self.canGoForward = wv.canGoForward
        }
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Coordinator が最新の self を参照するように差し替え
        context.coordinator.parent = self

        // もし外部から url が変わる可能性があれば再ロード
        // if nsView.url != url {
        //     nsView.load(URLRequest(url: url))
        // }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        // let → var に変更
        var parent: WebView

        private var backObs:   NSKeyValueObservation?
        private var fwdObs:    NSKeyValueObservation?
        private var titleObs:  NSKeyValueObservation?
        private var urlObs:    NSKeyValueObservation?

        init(_ parent: WebView) {
            self.parent = parent
        }

        // KVO の開始
        func observe(webView wv: WKWebView) {
            backObs = wv.observe(\.canGoBack, options: [.initial, .new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.canGoBack = wv.canGoBack
                }
            }
            fwdObs = wv.observe(\.canGoForward, options: [.initial, .new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.canGoForward = wv.canGoForward
                }
            }
            titleObs = wv.observe(\.title, options: [.initial, .new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.pageTitle = wv.title ?? ""
                }
            }
            urlObs = wv.observe(\.url, options: [.initial, .new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.pageURL = wv.url?.absoluteString ?? ""
                }
            }
        }

        // navigationDelegate の didFinish は補助的に
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // KVO で拾えないケースがあればここでも更新
            DispatchQueue.main.async {
                self.parent.pageTitle = webView.title ?? ""
                self.parent.pageURL   = webView.url?.absoluteString ?? ""
            }
        }

        deinit {
            backObs?.invalidate()
            fwdObs?.invalidate()
            titleObs?.invalidate()
            urlObs?.invalidate()
        }
    }
}

// ウィンドウへの参照取得用
struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            if let w = v.window {
                // タイトルバーを透明に…
                w.titlebarAppearsTransparent = true
                // …でもコンテンツ領域はタイトルバー下には広げない
                w.styleMask.remove(.fullSizeContentView)
                // 背景を黒く
                w.backgroundColor = .black
                // （オプション）背景クリックでドラッグ可能に
                w.isMovableByWindowBackground = true
                callback(w)
            }
        }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// メインの ContentView
struct ContentView: View {
    @State private var pageTitle     = "Loading..."
    @State private var pageURL       = ""
    @State private var nsWindow: NSWindow? = nil
    @State private var webView: WKWebView?   = nil
    @State private var canGoBack    = false
    @State private var canGoForward = false

    private let initialURL = URL(string: "https://diamondgotcat.net/")!

    var body: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            WebView(
                url: initialURL,
                pageTitle: $pageTitle,
                pageURL: $pageURL,
                webView: $webView,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward
            )
            .ignoresSafeArea()
            .background(
                WindowAccessor { window in
                    self.nsWindow = window
                    window.title = self.pageTitle
                }
            )
            .onChange(of: pageTitle) { new in
                nsWindow?.title = new
            }
            .toolbarBackground(Color.black, for: .automatic)
            .toolbarBackground(.visible,   for: .automatic)
            .toolbar {
                ToolbarItemGroup(placement: .principal) {
                    Button(action: { webView?.goBack() }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!canGoBack)
                    
                    Button(action: { webView?.goForward() }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!canGoForward)
                    
                    Divider()
                    
                    Button(action: {
                        webView?.load(URLRequest(url: initialURL))
                    }) {
                        Image(systemName: "house")
                        Text("Home")
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Text(pageURL)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .id(pageURL)
                }
            }
        }
    }
}

// アプリ本体
@main
struct WebViewToolbarApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}
