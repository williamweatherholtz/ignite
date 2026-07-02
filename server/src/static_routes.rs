//! Static + app-shell serving, wire-compatible with Ignis c9656b8 (index.js / cache-headers.js):
//! GET / index.html script injection, /vault-files/<vault>/<path>, ServeDir statics, and the
//! ?v= cache-control policy. The injection + cache logic are pure + fixture-tested; the real
//! Obsidian bundle + built Ignis JS are deploy-time assets.

use crate::fs_routes::resolve_in_vault;
use crate::registry::VaultRegistry;
use axum::{
    extract::{Path as AxPath, Request, State},
    http::{
        header::{CACHE_CONTROL, CONTENT_TYPE},
        HeaderValue, StatusCode,
    },
    middleware::Next,
    response::{IntoResponse, Response},
    Extension,
};
use std::path::PathBuf;
use std::sync::Arc;

/// Immutable-for-a-year (versioned) vs short-lived (unversioned) cache policy (cache-headers.js).
const IMMUTABLE: &str = "public, max-age=31536000, immutable";
const SHORT: &str = "public, max-age=300";

/// Paths + versions for the app shell (all env-configurable; injected for tests).
#[derive(Clone, Debug)]
pub struct StaticConfig {
    /// dir holding the ignis template `index.html` + the /assets/* files
    pub assets_dir: PathBuf,
    pub ui_dist: PathBuf,
    pub shim_dist: PathBuf,
    pub obsidian_assets: PathBuf,
    pub obsidian_version: Option<String>,
    pub ignis_version: String,
}

impl StaticConfig {
    /// From env: OBSIDIAN_ASSETS_PATH, IGNITE_ASSETS_DIR, IGNITE_UI_DIST, IGNITE_SHIM_DIST,
    /// OBSIDIAN_VERSION (unset/"0.0.0" => None). ignis_version = crate version.
    pub fn from_env() -> Self {
        let env_path =
            |k: &str, d: &str| PathBuf::from(std::env::var(k).unwrap_or_else(|_| d.to_string()));
        let ov = std::env::var("OBSIDIAN_VERSION").ok();
        let obsidian_version = match ov.as_deref() {
            None | Some("") | Some("0.0.0") => None,
            Some(v) => Some(v.to_string()),
        };
        StaticConfig {
            assets_dir: env_path("IGNITE_ASSETS_DIR", "./assets"),
            ui_dist: env_path("IGNITE_UI_DIST", "./packages/ui/dist"),
            shim_dist: env_path("IGNITE_SHIM_DIST", "./packages/shim/dist"),
            obsidian_assets: env_path("OBSIDIAN_ASSETS_PATH", "./obsidian"),
            obsidian_version,
            ignis_version: env!("CARGO_PKG_VERSION").to_string(),
        }
    }
}

/// Append `?v=`/`&v=` when a version is known; unchanged otherwise (Ignis versionedSrc).
fn versioned_src(src: &str, version: Option<&str>) -> String {
    match version {
        Some(v) => format!("{src}{}v={v}", if src.contains('?') { '&' } else { '?' }),
        None => src.to_string(),
    }
}

/// Build the shell HTML: discover Obsidian's `<script src>` tags, version-stamp them, and inject
/// them + the Ignis ui/shim scripts into the template (replicates Ignis index.js:124-174).
pub fn build_index_html(
    template: &str,
    obsidian_index_html: &str,
    obsidian_version: Option<&str>,
    ignis_version: &str,
) -> String {
    // Discover Obsidian's <script src="..."> tags (index.js scriptRegex) + version-stamp them.
    let re = regex::Regex::new(r#"<script[^>]+src="([^"]+)"[^>]*>"#).expect("valid regex");
    let scripts: Vec<String> = re
        .captures_iter(obsidian_index_html)
        .map(|c| versioned_src(&c[1], obsidian_version))
        .collect();
    let scripts_json = serde_json::to_string(&scripts).unwrap_or_else(|_| "[]".to_string());

    template
        .replace(
            "__IGNIS_UI_SRC__",
            &format!("ignis-ui.js?v={ignis_version}"),
        )
        .replace(
            "__SHIM_LOADER_SRC__",
            &format!("shim-loader.js?v={ignis_version}"),
        )
        .replace(
            "__APP_CSS_SRC__",
            &versioned_src("app.css", obsidian_version),
        )
        .replace("__OBSIDIAN_SCRIPTS__", &scripts_json)
}

/// Cache-Control for a static asset request, or None to leave defaults (cache-headers.js:
/// ASSET_EXT = js|css|woff|woff2|ttf|otf|wasm|map; versioned => immutable, else short).
pub fn cache_control_for(path: &str, has_version: bool) -> Option<&'static str> {
    let last = path.rsplit('/').next().unwrap_or("");
    let ext = last.rsplit_once('.').map(|(_, e)| e.to_ascii_lowercase());
    let is_asset = matches!(
        ext.as_deref(),
        Some("js" | "css" | "woff" | "woff2" | "ttf" | "otf" | "wasm" | "map")
    );
    if !is_asset {
        return None;
    }
    Some(if has_version { IMMUTABLE } else { SHORT })
}

/// Build the shell HTML from the on-disk template + Obsidian bundle index.html.
pub fn build_shell(cfg: &StaticConfig) -> std::io::Result<String> {
    let template = std::fs::read_to_string(cfg.assets_dir.join("index.html"))?;
    let obsidian = std::fs::read_to_string(cfg.obsidian_assets.join("index.html"))?;
    Ok(build_index_html(
        &template,
        &obsidian,
        cfg.obsidian_version.as_deref(),
        &cfg.ignis_version,
    ))
}

/// GET / and /index.html — the app shell (Content-Type text/html, Cache-Control no-cache).
pub(crate) async fn index_handler(Extension(cfg): Extension<Arc<StaticConfig>>) -> Response {
    match build_shell(&cfg) {
        Ok(html) => (
            [
                (CONTENT_TYPE, "text/html; charset=utf-8"),
                (CACHE_CONTROL, "no-cache"),
            ],
            html,
        )
            .into_response(),
        Err(_) => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
    }
}

/// GET /vault-files/<vaultId>/<relpath> — serve a vault resource (image/attachment),
/// within-vault (traversal rejected via resolve_in_vault). 404 unknown vault / missing file.
pub(crate) async fn vault_files_handler(
    State(reg): State<Arc<VaultRegistry>>,
    AxPath((vault, rest)): AxPath<(String, String)>,
) -> Response {
    let Some(root) = reg.get(&vault).map(|v| v.root().to_path_buf()) else {
        return (StatusCode::NOT_FOUND, "vault not found").into_response();
    };
    let p = match resolve_in_vault(&root, &rest) {
        Ok(p) => p,
        Err(e) => return e.into_response(),
    };
    match std::fs::read(&p) {
        Ok(bytes) => {
            let mime = mime_guess::from_path(&p).first_or_octet_stream();
            ([(CONTENT_TYPE, mime.as_ref())], bytes).into_response()
        }
        Err(_) => (StatusCode::NOT_FOUND, "not found").into_response(),
    }
}

/// Middleware: set the ?v-aware Cache-Control for managed asset extensions, only when the
/// response hasn't already set it (mirrors express.static's "fill only when absent").
pub(crate) async fn cache_control_mw(req: Request, next: Next) -> Response {
    let has_v = req
        .uri()
        .query()
        .map(|q| q.split('&').any(|kv| kv == "v" || kv.starts_with("v=")))
        .unwrap_or(false);
    let path = req.uri().path().to_string();
    let mut resp = next.run(req).await;
    if !resp.headers().contains_key(CACHE_CONTROL) {
        if let Some(cc) = cache_control_for(&path, has_v) {
            resp.headers_mut()
                .insert(CACHE_CONTROL, HeaderValue::from_static(cc));
        }
    }
    resp
}

#[cfg(test)]
mod tests {
    use super::*;

    const TEMPLATE: &str = r#"<!doctype html><html><head>
<link rel="stylesheet" href="__APP_CSS_SRC__">
<script src="__IGNIS_UI_SRC__"></script>
<script src="__SHIM_LOADER_SRC__"></script>
<script>window.__OBSIDIAN_SCRIPTS__ = __OBSIDIAN_SCRIPTS__;</script>
</head><body class="theme-dark"></body></html>"#;

    const OBSIDIAN_HTML: &str = r#"<html><head>
<script src="app.js"></script>
<script defer src="lib/extra.js"></script>
</head></html>"#;

    #[test]
    fn build_index_html_injects_versioned_obsidian_and_ignis_scripts() {
        let out = build_index_html(TEMPLATE, OBSIDIAN_HTML, Some("1.12.7"), "0.1.0");
        // ignis scripts version-stamped by the ignis version
        assert!(out.contains("ignis-ui.js?v=0.1.0"));
        assert!(out.contains("shim-loader.js?v=0.1.0"));
        // app.css version-stamped by the obsidian version
        assert!(out.contains("app.css?v=1.12.7"));
        // both obsidian script srcs discovered + version-stamped, embedded as a JSON array
        assert!(out.contains("app.js?v=1.12.7"));
        assert!(out.contains("lib/extra.js?v=1.12.7"));
        // no leftover placeholders
        assert!(!out.contains("__OBSIDIAN_SCRIPTS__"));
        assert!(!out.contains("__IGNIS_UI_SRC__"));
    }

    #[test]
    fn build_index_html_omits_version_when_unknown() {
        let out = build_index_html(TEMPLATE, OBSIDIAN_HTML, None, "0.1.0");
        assert!(out.contains("app.js")); // present
        assert!(!out.contains("app.js?v=")); // but NOT version-stamped
        assert!(out.contains("ignis-ui.js?v=0.1.0")); // ignis still versioned by its own version
    }

    #[test]
    fn cache_control_versioned_vs_unversioned_vs_nonasset() {
        assert_eq!(cache_control_for("/ignis-ui.js", true), Some(IMMUTABLE));
        assert_eq!(cache_control_for("/ignis-ui.js", false), Some(SHORT));
        assert_eq!(cache_control_for("/app.css", true), Some(IMMUTABLE));
        assert_eq!(cache_control_for("/logo.png", true), None); // not a managed asset ext
        assert_eq!(cache_control_for("/", false), None);
    }
}
