//! POST /api/proxy — forward a request to an external URL to bypass CORS.
//! Wire-compatible with Ignis c9656b8 (base64-in-JSON envelope, per dProxyWireCompat):
//! request `{url, method?, headers?, body?, binary?}` -> `{status, headers, body:<base64>}`.
//! SSRF guard (private/loopback/link-local rejected unless allow-listed) with a re-check at
//! every redirect hop; Authorization/Cookie stripped on cross-origin redirect; 50 MB cap.

use axum::{
    response::{IntoResponse, Response},
    routing::post,
    Extension, Json, Router,
};
use base64::Engine;
use futures_util::StreamExt;
use serde::Deserialize;
use serde_json::{json, Map, Value};
use std::collections::HashSet;
use std::net::IpAddr;
use std::sync::Arc;

const MAX_RESPONSE_BYTES: u64 = 50 * 1024 * 1024;
const MAX_REDIRECTS: usize = 5;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ProxyMode {
    Any,
    Allowlist,
    Disabled,
}

/// Proxy configuration, threaded as an `Extension` so tests inject it without touching
/// process env.
#[derive(Clone)]
pub struct ProxyConfig {
    pub mode: ProxyMode,
    /// exact IPs that are allowed even though private (PROXY_ALLOW_PRIVATE_HOSTS)
    pub allow_private_exact: HashSet<IpAddr>,
    /// IPv4 CIDRs (network, mask) allowed even though private
    pub allow_private_cidr_v4: Vec<(u32, u32)>,
    /// host allowlist used when mode == Allowlist (PROXY_ALLOWLIST)
    pub allowlist_hosts: Vec<String>,
}

impl Default for ProxyConfig {
    fn default() -> Self {
        Self {
            mode: ProxyMode::Any,
            allow_private_exact: HashSet::new(),
            allow_private_cidr_v4: Vec::new(),
            allowlist_hosts: Vec::new(),
        }
    }
}

impl ProxyConfig {
    pub fn from_env() -> Self {
        let mode = match std::env::var("PROXY_MODE").unwrap_or_default().as_str() {
            "disabled" => ProxyMode::Disabled,
            "allowlist" => ProxyMode::Allowlist,
            _ => ProxyMode::Any,
        };
        let mut cfg = ProxyConfig {
            mode,
            ..Default::default()
        };
        if let Ok(v) = std::env::var("PROXY_ALLOW_PRIVATE_HOSTS") {
            cfg.set_allow_private(&v);
        }
        if let Ok(v) = std::env::var("PROXY_ALLOWLIST") {
            cfg.allowlist_hosts = v
                .split(',')
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .collect();
        }
        cfg
    }

    /// Parse a comma-separated allow list of exact IPs and IPv4 CIDRs (matches Ignis buildAllowList).
    pub fn set_allow_private(&mut self, entries: &str) {
        for entry in entries.split(',').map(|s| s.trim()).filter(|s| !s.is_empty()) {
            if let Some((base, prefix)) = entry.split_once('/') {
                if let (Ok(std::net::Ipv4Addr { .. }), Ok(p)) =
                    (base.parse::<std::net::Ipv4Addr>(), prefix.parse::<u32>())
                {
                    if p <= 32 {
                        let base_ip: std::net::Ipv4Addr = base.parse().unwrap();
                        let mask: u32 = if p == 0 { 0 } else { u32::MAX << (32 - p) };
                        let network = u32::from(base_ip) & mask;
                        self.allow_private_cidr_v4.push((network, mask));
                    }
                }
            } else if let Ok(ip) = entry.parse::<IpAddr>() {
                self.allow_private_exact.insert(ip);
            }
        }
    }

    fn allowlisted_addr(&self, ip: IpAddr) -> bool {
        if self.allow_private_exact.contains(&ip) {
            return true;
        }
        if let IpAddr::V4(v4) = ip {
            let value = u32::from(v4);
            for (network, mask) in &self.allow_private_cidr_v4 {
                if value & mask == *network {
                    return true;
                }
            }
        }
        false
    }

    /// A public address always passes; a private one passes only when allow-listed.
    fn addr_allowed(&self, ip: IpAddr) -> bool {
        !is_private_ip(ip) || self.allowlisted_addr(ip)
    }
}

/// Matches Ignis isPrivateIp: 0/8, 10/8, 127/8, 169.254/16, 172.16-31, 192.168/16,
/// 100.64-127 (CGNAT); v6 ::1/::, fe8-b (link-local), fc/fd (ULA), and v4-mapped.
pub fn is_private_ip(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(v4) => {
            let o = v4.octets();
            o[0] == 0
                || o[0] == 10
                || o[0] == 127
                || (o[0] == 169 && o[1] == 254)
                || (o[0] == 172 && (16..=31).contains(&o[1]))
                || (o[0] == 192 && o[1] == 168)
                || (o[0] == 100 && (64..=127).contains(&o[1]))
        }
        IpAddr::V6(v6) => {
            if v6.is_loopback() || v6.is_unspecified() {
                return true;
            }
            if let Some(v4) = v6.to_ipv4_mapped() {
                return is_private_ip(IpAddr::V4(v4));
            }
            let seg = v6.segments()[0];
            // fe80::/10 link-local
            (0xfe80..=0xfebf).contains(&seg)
                // fc00::/7 unique-local (fc/fd)
                || (0xfc00..=0xfdff).contains(&seg)
        }
    }
}

#[derive(Deserialize)]
struct ProxyReq {
    url: Option<String>,
    method: Option<String>,
    headers: Option<Map<String, Value>>,
    body: Option<String>,
    binary: Option<bool>,
}

fn err(status: u16, msg: &str) -> Response {
    (
        axum::http::StatusCode::from_u16(status).unwrap_or(axum::http::StatusCode::BAD_GATEWAY),
        Json(json!({ "error": msg })),
    )
        .into_response()
}

pub fn routes() -> Router<Arc<crate::registry::VaultRegistry>> {
    Router::new().route("/api/proxy", post(proxy_handler))
}

fn header_map_to_json(headers: &reqwest::header::HeaderMap) -> Map<String, Value> {
    let mut out = Map::new();
    for (name, value) in headers.iter() {
        if let Ok(v) = value.to_str() {
            out.insert(name.as_str().to_string(), Value::String(v.to_string()));
        }
    }
    out
}

/// Resolve the URL's host and reject if any resolved address is private and not allow-listed.
/// (Re-checked at every redirect hop.) TOCTOU note: resolution here can differ from reqwest's
/// connect-time resolution (DNS rebinding) — matches Ignis's model; not hardened further.
async fn addr_ok(cfg: &ProxyConfig, url: &reqwest::Url) -> Result<(), Response> {
    let host = match url.host_str() {
        Some(h) => h,
        None => return Err(err(400, "invalid url host")),
    };
    let port = url.port_or_known_default().unwrap_or(80);
    let addrs = match tokio::net::lookup_host((host, port)).await {
        Ok(a) => a,
        Err(_) => return Err(err(502, "dns resolution failed")),
    };
    let mut any = false;
    for addr in addrs {
        any = true;
        if !cfg.addr_allowed(addr.ip()) {
            return Err(err(403, "address not allowed"));
        }
    }
    if !any {
        return Err(err(502, "no addresses resolved"));
    }
    Ok(())
}

async fn proxy_handler(
    Extension(cfg): Extension<Arc<ProxyConfig>>,
    Json(req): Json<ProxyReq>,
) -> Response {
    if cfg.mode == ProxyMode::Disabled {
        return err(403, "proxy disabled");
    }
    let url = match req.url.as_deref() {
        Some(u) if !u.is_empty() => u,
        _ => return err(400, "url required"),
    };
    let mut current = match reqwest::Url::parse(url) {
        Ok(u) => u,
        Err(_) => return err(400, "invalid url"),
    };
    if !matches!(current.scheme(), "http" | "https") {
        return err(400, "unsupported url scheme");
    }
    if cfg.mode == ProxyMode::Allowlist {
        let host = current.host_str().unwrap_or("");
        if !cfg.allowlist_hosts.iter().any(|h| h == host) {
            return err(403, "host not allowlisted");
        }
    }

    let mut method = reqwest::Method::from_bytes(
        req.method
            .as_deref()
            .unwrap_or("GET")
            .to_uppercase()
            .as_bytes(),
    )
    .unwrap_or(reqwest::Method::GET);

    let mut headers = reqwest::header::HeaderMap::new();
    if let Some(h) = &req.headers {
        for (k, v) in h {
            if let Some(s) = v.as_str() {
                if let (Ok(name), Ok(val)) = (
                    reqwest::header::HeaderName::from_bytes(k.as_bytes()),
                    reqwest::header::HeaderValue::from_str(s),
                ) {
                    let lname = name.as_str().to_ascii_lowercase();
                    if lname != "host" && lname != "content-length" {
                        headers.insert(name, val);
                    }
                }
            }
        }
    }

    let body_bytes: Option<Vec<u8>> = match &req.body {
        Some(b) if req.binary.unwrap_or(false) => {
            match base64::engine::general_purpose::STANDARD.decode(b) {
                Ok(d) => Some(d),
                Err(_) => return err(400, "invalid base64 body"),
            }
        }
        Some(b) => Some(b.clone().into_bytes()),
        None => None,
    };

    let client = match reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .build()
    {
        Ok(c) => c,
        Err(_) => return err(502, "client build failed"),
    };

    let origin = current.origin();
    let mut hops = 0usize;
    let resp = loop {
        if let Err(e) = addr_ok(&cfg, &current).await {
            return e;
        }
        let mut rb = client
            .request(method.clone(), current.clone())
            .headers(headers.clone());
        if let Some(b) = &body_bytes {
            rb = rb.body(b.clone());
        }
        let resp = match rb.send().await {
            Ok(r) => r,
            Err(_) => return err(502, "upstream request failed"),
        };
        if resp.status().is_redirection() && hops < MAX_REDIRECTS {
            if let Some(loc) = resp
                .headers()
                .get(reqwest::header::LOCATION)
                .and_then(|v| v.to_str().ok())
            {
                if let Ok(next) = current.join(loc) {
                    if matches!(next.scheme(), "http" | "https") {
                        if next.origin() != origin {
                            headers.remove(reqwest::header::AUTHORIZATION);
                            headers.remove(reqwest::header::COOKIE);
                        }
                        let code = resp.status().as_u16();
                        if code == 303
                            || ((code == 301 || code == 302) && method != reqwest::Method::HEAD)
                        {
                            method = reqwest::Method::GET;
                        }
                        current = next;
                        hops += 1;
                        continue;
                    }
                }
            }
        }
        break resp;
    };

    let status = resp.status().as_u16();
    let resp_headers = header_map_to_json(resp.headers());

    // Stream the body and base64-encode INCREMENTALLY (dProxyWireCompat: keep the base64-JSON
    // wire, but never hold the full raw body — only a 0-2 byte carry + the growing base64).
    let mut stream = resp.bytes_stream();
    let mut b64 = String::new();
    let mut carry: Vec<u8> = Vec::new();
    let mut total: u64 = 0;
    let no_pad = base64::engine::general_purpose::STANDARD_NO_PAD;
    while let Some(chunk) = stream.next().await {
        let chunk = match chunk {
            Ok(c) => c,
            Err(_) => return err(502, "upstream body error"),
        };
        total += chunk.len() as u64;
        if total > MAX_RESPONSE_BYTES {
            return err(502, "response too large");
        }
        carry.extend_from_slice(&chunk);
        let n = (carry.len() / 3) * 3;
        if n > 0 {
            b64.push_str(&no_pad.encode(&carry[..n]));
            carry.drain(..n);
        }
    }
    if !carry.is_empty() {
        b64.push_str(&base64::engine::general_purpose::STANDARD.encode(&carry));
    }

    Json(json!({
        "status": status,
        "headers": Value::Object(resp_headers),
        "body": b64,
    }))
    .into_response()
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::Body;
    use axum::http::Request;
    use tower::ServiceExt;

    #[test]
    fn private_ip_classification_matches_ignis() {
        for s in ["10.0.0.1", "127.0.0.1", "192.168.1.1", "169.254.1.1", "172.16.0.1", "::1"] {
            assert!(is_private_ip(s.parse().unwrap()), "{s} should be private");
        }
        for s in ["8.8.8.8", "1.1.1.1", "203.0.113.5"] {
            assert!(!is_private_ip(s.parse().unwrap()), "{s} should be public");
        }
    }

    #[test]
    fn allow_private_exact_and_cidr() {
        let mut cfg = ProxyConfig::default();
        cfg.set_allow_private("127.0.0.1, 10.0.0.0/8");
        assert!(cfg.addr_allowed("127.0.0.1".parse().unwrap()));
        assert!(cfg.addr_allowed("10.5.6.7".parse().unwrap()));
        assert!(!cfg.addr_allowed("192.168.1.1".parse().unwrap()));
        assert!(cfg.addr_allowed("8.8.8.8".parse().unwrap()));
    }

    // spin a mock upstream on 127.0.0.1:0, return its base URL
    async fn mock_upstream() -> String {
        let app = Router::new().route(
            "/hello",
            axum::routing::get(|| async { ([("x-test", "yes")], "hello-upstream") }),
        );
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        tokio::spawn(async move {
            axum::serve(listener, app).await.unwrap();
        });
        format!("http://127.0.0.1:{}", addr.port())
    }

    fn router(cfg: ProxyConfig) -> Router {
        let reg = Arc::new(crate::registry::VaultRegistry::default());
        routes().layer(Extension(Arc::new(cfg))).with_state(reg)
    }

    async fn post_proxy(app: Router, body: Value) -> (axum::http::StatusCode, Value) {
        let resp = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/api/proxy")
                    .header("content-type", "application/json")
                    .body(Body::from(body.to_string()))
                    .unwrap(),
            )
            .await
            .unwrap();
        let status = resp.status();
        let bytes = axum::body::to_bytes(resp.into_body(), usize::MAX).await.unwrap();
        let v: Value = serde_json::from_slice(&bytes).unwrap_or(Value::Null);
        (status, v)
    }

    #[tokio::test]
    async fn proxies_a_get_and_returns_base64_envelope() {
        let base = mock_upstream().await;
        let mut cfg = ProxyConfig::default();
        cfg.set_allow_private("127.0.0.1"); // reach the loopback mock
        let (status, v) = post_proxy(router(cfg), json!({ "url": format!("{base}/hello") })).await;
        assert_eq!(status, 200);
        assert_eq!(v["status"], 200);
        let b64 = v["body"].as_str().unwrap();
        let decoded = base64::engine::general_purpose::STANDARD.decode(b64).unwrap();
        assert_eq!(decoded, b"hello-upstream");
        assert_eq!(v["headers"]["x-test"], "yes");
    }

    #[tokio::test]
    async fn ssrf_guard_rejects_private_without_allowlist() {
        let base = mock_upstream().await;
        let cfg = ProxyConfig::default(); // no allowlist -> 127.0.0.1 blocked
        let (status, _v) = post_proxy(router(cfg), json!({ "url": format!("{base}/hello") })).await;
        assert_eq!(status, 403);
    }

    #[tokio::test]
    async fn disabled_mode_rejects() {
        let cfg = ProxyConfig {
            mode: ProxyMode::Disabled,
            ..Default::default()
        };
        let (status, _v) = post_proxy(router(cfg), json!({ "url": "http://8.8.8.8/" })).await;
        assert_eq!(status, 403);
    }

    #[tokio::test]
    async fn missing_url_is_400() {
        let (status, _v) = post_proxy(router(ProxyConfig::default()), json!({})).await;
        assert_eq!(status, 400);
    }
}
