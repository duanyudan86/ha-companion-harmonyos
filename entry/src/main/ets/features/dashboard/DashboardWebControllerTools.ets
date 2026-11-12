import web_webview from '@ohos.web.webview';

export class DashboardWebControllerTools {
  static runScript(
    controller: web_webview.WebviewController,
    script: string,
    onResolve?: (raw: Object | string | number | ArrayBuffer) => void
  ): void {
    try {
      const promise = controller.runJavaScript(script);
      if (onResolve) {
        promise.then((raw: Object | string | number | ArrayBuffer): void => {
          onResolve(raw);
        }).catch((): void => {
          onResolve('false');
        });
      } else {
        promise.catch((): void => {});
      }
    } catch (_) {
      // Ignore while the WebView is not attached yet.
      if (onResolve) {
        onResolve('false');
      }
    }
  }

  static refresh(controller: web_webview.WebviewController): void {
    try {
      controller.refresh();
    } catch (_) {
      // Ignore while the WebView is not attached yet.
    }
  }

  static loadUrl(controller: web_webview.WebviewController, url: string): void {
    try {
      controller.loadUrl(url);
    } catch (_) {
      // Ignore while the WebView is not attached yet.
    }
  }

}
