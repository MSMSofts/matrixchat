  if (window.opener) {
    window.opener.postMessage({
      'flutter-web-auth-2': window.location.href
    }, window.location.origin);
  } else {
    localStorage.setItem('flutter-web-auth-2', window.location.href);
  }
  // The receiving auth plugin still requires its original callback URL.
  // Remove it from the popup's address/history after delivering the result.
  try {
    window.history.replaceState(null, "", window.location.pathname);
  } catch (_) {
    // A restricted browser history must not break the authentication callback.
  }
  window.close();
