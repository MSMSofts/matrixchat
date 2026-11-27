  if (window.opener) {
    window.opener.postMessage({
      'flutter-web-auth-2': window.location.href
    }, window.location.origin);
  } else {
    localStorage.setItem('flutter-web-auth-2', window.location.href);
  }
  window.close();
