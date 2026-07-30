"use strict";

if (["localhost", "127.0.0.1", "[::1]"].includes(location.hostname)) {
  self.FIREBASE_APPCHECK_DEBUG_TOKEN = true;
}

if ("serviceWorker" in navigator) {
  window.addEventListener("load", function () {
    navigator.serviceWorker.getRegistrations().then(function (registrations) {
      registrations.forEach(function (registration) {
        const scriptUrl = registration.active?.scriptURL
          || registration.waiting?.scriptURL
          || registration.installing?.scriptURL
          || "";

        if (scriptUrl.endsWith("/sw.js")) {
          registration.unregister();
        }
      });
    });
  });
}

window.addEventListener("load", function () {
  const baseElement = document.querySelector("base");
  const basePath = baseElement?.getAttribute("href") || "/";
  const basePathWithoutSlash = basePath.endsWith("/")
    ? basePath.slice(0, -1)
    : basePath;
  const isPwa = window.matchMedia("(display-mode: standalone)").matches
    || window.navigator.standalone === true
    || document.referrer.includes("android-app://");

  if (isPwa) {
    if (window.location.pathname !== basePath
        && window.location.pathname !== basePath + "index.html") {
      window.history.replaceState({}, "", basePath);
    }
    return;
  }

  const path = window.location.pathname;
  const hash = window.location.hash;

  if (path !== basePath && path !== basePath + "index.html") {
    const url = new URL(window.location.href);
    const relativePath = path.startsWith(basePathWithoutSlash)
      ? path.substring(basePathWithoutSlash.length)
      : path;

    url.searchParams.set("route", relativePath);
    if (hash) {
      url.searchParams.set("hash", hash.substring(1));
    }
    window.history.replaceState({}, "", url);
  } else if (hash) {
    const url = new URL(window.location.href);
    url.searchParams.set("route", hash.substring(1));
    window.history.replaceState({}, "", url);
  }
});

window.addEventListener("flutter-first-frame", function () {
  const loading = document.querySelector("#loading");
  if (loading) {
    loading.style.display = "none";
  }
  document.body.style.background = "transparent";
});
