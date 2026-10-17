{{flutter_js}}
{{flutter_build_config}}

// No service worker: an offline copy would keep serving an old version of
// the site after a deploy (see tools/web/build.sh).
_flutter.loader.load();
