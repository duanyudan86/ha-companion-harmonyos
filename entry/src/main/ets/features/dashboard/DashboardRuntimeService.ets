// Runtime actions for the embedded Home Assistant dashboard WebView.
// Navigation, reload, external auth, and dashboard lifecycle behavior should flow through this layer.
import web_webview from '@ohos.web.webview';
import { AppRoute } from '../../app/AppRoute';
import { AppNavigator } from '../../app/AppNavigator';
import { UrlService } from '../../services/UrlService';
import { DashboardWebControllerTools } from './DashboardWebControllerTools';

export interface DashboardRuntimeState {
  showLoginWeb: boolean;
  authUrl: string;
  dashboardUrl: string;
  dashboardCurrentUrl: string;
  dashboardClearHistoryPending: boolean;
  dashboardAuthProvided: boolean;
  pageZoomLevel: string;
  alwaysShowFirstViewOnAppStartEnabled: boolean;
  haBaseUrl: string;
  addingServerFromSettings: boolean;
  onboardingBackTarget: number;
  dashboardBridgeReady: boolean;
  step: AppRoute;
  message: string;
}

export interface DashboardRuntimeCallbacks {
  applyActiveTheme: () => void;
  applyWindowPreferences: () => void;
  applyDashboardPreferences: () => void;
}

export class DashboardRuntimeService {
  static openDashboard(state: DashboardRuntimeState, callbacks: DashboardRuntimeCallbacks): void {
    const baseUrl = UrlService.normalizeBaseUrl(state.haBaseUrl);
    state.dashboardUrl = UrlService.buildDashboardUrl(baseUrl);
    state.dashboardCurrentUrl = state.dashboardUrl;
    state.dashboardClearHistoryPending = true;
    state.addingServerFromSettings = false;
    state.onboardingBackTarget = AppRoute.WELCOME;
    state.step = AppRoute.DASHBOARD;
    state.authUrl = '';
    state.showLoginWeb = false;
    state.dashboardBridgeReady = false;
    state.dashboardAuthProvided = false;
    callbacks.applyActiveTheme();
    callbacks.applyWindowPreferences();
    callbacks.applyDashboardPreferences();
    state.message = '';
  }

  static isWebControllerMounted(state: DashboardRuntimeState): boolean {
    if (state.showLoginWeb && state.authUrl.trim().length > 0) {
      return true;
    }
    return DashboardRuntimeService.isDashboardWebMounted(state);
  }

  static isDashboardWebMounted(state: DashboardRuntimeState): boolean {
    if (state.dashboardUrl.trim().length === 0) {
      return false;
    }
    return state.step === AppRoute.DASHBOARD || AppNavigator.isNativeOverlay(state.step);
  }

  static runScript(
    controller: web_webview.WebviewController,
    script: string,
    onResolve?: (raw: Object | string | number | ArrayBuffer) => void
  ): void {
    DashboardWebControllerTools.runScript(controller, script, onResolve);
  }

  static refresh(controller: web_webview.WebviewController): void {
    DashboardWebControllerTools.refresh(controller);
  }

  static loadUrl(controller: web_webview.WebviewController, url: string): void {
    DashboardWebControllerTools.loadUrl(controller, url);
  }

  static navigateDashboardView(controller: web_webview.WebviewController, direction: number): void {
    const step = direction < 0 ? -1 : 1;
    DashboardRuntimeService.runScript(controller, `(function(){` +
      `var ha=document.querySelector('home-assistant');` +
      `if(!ha){return;}` +
      `var hass=ha&&ha.hass;` +
      `var panelUrl=hass&&hass.panelUrl||'';` +
      `var panelInfo=panelUrl&&hass.panels?hass.panels[panelUrl]:null;` +
      `var panelName=panelInfo&&panelInfo.component_name==='home'?'ha-panel-home':'ha-panel-lovelace';` +
      `var main=ha&&ha.shadowRoot?ha.shadowRoot.querySelector('home-assistant-main'):null;` +
      `var resolver=main&&main.shadowRoot?main.shadowRoot.querySelector('partial-panel-resolver'):null;` +
      `var panel=resolver?resolver.querySelector(panelName):null;` +
      `var root=panel&&panel.shadowRoot?panel.shadowRoot.querySelector('hui-root'):null;` +
      `var tabGroup=root&&root.shadowRoot?root.shadowRoot.querySelector('ha-tab-group'):null;` +
      `if(!tabGroup){return;}` +
      `var tabs=Array.prototype.slice.call(tabGroup.querySelectorAll('ha-tab-group-tab')).filter(function(tab){` +
      `return !tab.disabled&&!tab.hasAttribute('disabled')&&!tab.classList.contains('hide-tab');` +
      `});` +
      `var active=tabs.findIndex(function(tab){return tab.active===true||tab.hasAttribute('active');});` +
      `var target=active+(${step});` +
      `if(active<0||target<0||target>=tabs.length){return;}` +
      `tabs[target].click();` +
      `})();`);
  }

  static applyDashboardPreferences(controller: web_webview.WebviewController, state: DashboardRuntimeState): void {
    if (!DashboardRuntimeService.isDashboardWebMounted(state)) {
      return;
    }
    DashboardWebControllerTools.applyZoom(controller, state.pageZoomLevel);
  }

  static refreshDashboardTheme(controller: web_webview.WebviewController, state: DashboardRuntimeState): void {
    if (!DashboardRuntimeService.isDashboardWebMounted(state)) {
      return;
    }
    DashboardRuntimeService.refresh(controller);
  }

  static installFrontendUrlObserver(controller: web_webview.WebviewController, state: DashboardRuntimeState): void {
    if (!DashboardRuntimeService.isDashboardWebMounted(state)) {
      return;
    }
    DashboardRuntimeService.runScript(controller, DashboardRuntimeService.frontendUrlObserverScript());
  }

  private static frontendUrlObserverScript(): string {
    return `(function(){` +
      `if(window.__haHarmonyUrlObserverInstalled){return;}` +
      `window.__haHarmonyUrlObserverInstalled=true;` +
      `window.__haHarmonyLastUrl='';` +
      `window.__haHarmonyLastDashboardView='';` +
      `function isDashboardView(){` +
      `try{` +
      `var ha=document.querySelector('home-assistant');` +
      `var hass=ha&&ha.hass;` +
      `var panelUrl=hass&&hass.panelUrl||'';` +
      `var panel=panelUrl&&hass.panels?hass.panels[panelUrl]:null;` +
      `if(!panel||(panel.component_name!=='lovelace'&&panel.component_name!=='home')){return false;}` +
      `if(history.state&&history.state.dialog==='ha-more-info-dialog'){return false;}` +
      `var path=String(location.pathname||'');` +
      `while(path.indexOf('/')===0){path=path.substring(1);}` +
      `while(path.length>0&&path.charAt(path.length-1)==='/'){path=path.substring(0,path.length-1);}` +
      `var segmentCount=path.length===0?0:path.split('/').length;` +
      `return segmentCount<=2;` +
      `}catch(e){return false;}` +
      `}` +
      `function notify(){` +
      `var url=String(location.href||'');` +
      `var dashboardView=isDashboardView();` +
      `var dashboardViewKey=dashboardView?'1':'0';` +
      `if(!url||(url===window.__haHarmonyLastUrl&&dashboardViewKey===window.__haHarmonyLastDashboardView)){return;}` +
      `window.__haHarmonyLastUrl=url;` +
      `window.__haHarmonyLastDashboardView=dashboardViewKey;` +
      `try{externalApp.externalBus(JSON.stringify({type:'harmony_url_changed',payload:{url:url,isDashboardView:dashboardView}}));}catch(e){}` +
      `}` +
      `function wrap(name){` +
      `var original=history[name];` +
      `if(typeof original!=='function'||original.__haHarmonyWrapped){return;}` +
      `history[name]=function(){var result=original.apply(this,arguments);setTimeout(notify,0);return result;};` +
      `history[name].__haHarmonyWrapped=true;` +
      `}` +
      `wrap('pushState');wrap('replaceState');` +
      `window.addEventListener('popstate',notify,true);` +
      `window.addEventListener('hashchange',notify,true);` +
      `setInterval(notify,1000);` +
      `notify();` +
      `})();`;
  }

  static shouldKeepCurrentDashboardPage(currentUrl: string): boolean {
    const path = UrlService.urlPathOnly(currentUrl);
    if (path.startsWith('/config/') && !path.startsWith('/config/dashboard')) {
      return true;
    }
    return path.startsWith('/hassio');
  }

  static maybeResetDashboardToFirstView(
    controller: web_webview.WebviewController,
    state: DashboardRuntimeState
  ): void {
    if (!state.alwaysShowFirstViewOnAppStartEnabled || state.haBaseUrl.trim().length === 0) {
      return;
    }
    if (DashboardRuntimeService.shouldKeepCurrentDashboardPage(state.dashboardCurrentUrl)) {
      return;
    }
    const url = UrlService.buildDashboardUrl(UrlService.normalizeBaseUrl(state.haBaseUrl));
    state.dashboardUrl = url;
    state.dashboardCurrentUrl = url;
    state.dashboardClearHistoryPending = true;
    DashboardRuntimeService.loadUrl(controller, url);
  }
}
