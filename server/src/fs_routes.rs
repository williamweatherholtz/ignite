//! The fs CRUD routes, wire-compatible with Ignis c9656b8. Every path is resolved
//! WITHIN the vault (traversal rejected). Writes are honest + durable (dCritiqueCorrectness
//! #3): real bytes to disk + fsync, real mtime/size read back, no synthetic metadata, no
//! coalescing. The index/WS stay correct via the live watcher (we never mutate the index here).

use crate::registry::VaultRegistry;
use axum::{
    extract::{Query, State},
    http::{header::CONTENT_TYPE, StatusCode},
    response::{IntoResponse, Json, Response},
    routing::{delete, get, post},
    Router,
};
use base64::{engine::general_purpose::STANDARD, Engine};
use serde::Deserialize;
use serde_json::json;
use std::io::Write;
use std::path::{Component, Path, PathBuf};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

// ---- errors (sanitized: never leak host paths or stack traces) ----
pub(crate) enum ApiError {
    BadRequest(&'static str),
    NotFound,
    Io(std::io::ErrorKind),
}
impl From<std::io::Error> for ApiError {
    fn from(e: std::io::Error) -> Self {
        ApiError::Io(e.kind())
    }
}
impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        use std::io::ErrorKind;
        let (status, msg): (StatusCode, &str) = match self {
            ApiError::BadRequest(m) => (StatusCode::BAD_REQUEST, m),
            ApiError::NotFound => (StatusCode::NOT_FOUND, "not found"),
            ApiError::Io(ErrorKind::NotFound) => (StatusCode::NOT_FOUND, "not found"),
            ApiError::Io(ErrorKind::PermissionDenied) => {
                (StatusCode::FORBIDDEN, "permission denied")
            }
            ApiError::Io(_) => (StatusCode::INTERNAL_SERVER_ERROR, "io error"),
        };
        (status, Json(json!({ "error": msg }))).into_response()
    }
}

fn to_ms(t: SystemTime) -> f64 {
    t.duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as f64)
        .unwrap_or(0.0)
}

/// Resolve a vault-relative path to an absolute path INSIDE `root`, rejecting any
/// traversal that would escape (leading-slash absolute, `..` above root, drive prefix).
/// Purely lexical (matches Ignis's textual containment); symlink canonicalization is
/// separately tracked.
pub(crate) fn resolve_in_vault(root: &Path, rel: &str) -> Result<PathBuf, ApiError> {
    let rel = rel.trim_start_matches(['/', '\\']);
    let mut out = root.to_path_buf();
    let mut depth: i32 = 0;
    for comp in Path::new(rel).components() {
        match comp {
            Component::Normal(c) => {
                out.push(c);
                depth += 1;
            }
            Component::CurDir => {}
            Component::ParentDir => {
                if depth == 0 {
                    return Err(ApiError::BadRequest("path escapes vault"));
                }
                depth -= 1;
                out.pop();
            }
            Component::RootDir | Component::Prefix(_) => {
                return Err(ApiError::BadRequest("absolute path not allowed"));
            }
        }
    }
    Ok(out)
}

fn vault_root(reg: &VaultRegistry, name: &Option<String>) -> Result<PathBuf, ApiError> {
    let name = name
        .as_deref()
        .ok_or(ApiError::BadRequest("vault required"))?;
    reg.get(name)
        .map(|v| v.root().to_path_buf())
        .ok_or(ApiError::NotFound)
}

// resolve (vault, path) for GET/DELETE query handlers
fn resolve_q(reg: &VaultRegistry, q: &FsQuery) -> Result<PathBuf, ApiError> {
    let root = vault_root(reg, &q.vault)?;
    let rel = q
        .path
        .as_deref()
        .ok_or(ApiError::BadRequest("path required"))?;
    resolve_in_vault(&root, rel)
}

#[derive(Deserialize, Default)]
struct FsQuery {
    vault: Option<String>,
    path: Option<String>,
    encoding: Option<String>,
    recursive: Option<String>,
}

// ---- GET /api/fs/stat ----
async fn stat(
    State(reg): State<Arc<VaultRegistry>>,
    Query(q): Query<FsQuery>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let p = resolve_q(&reg, &q)?;
    let m = std::fs::metadata(&p)?;
    let ty = if m.is_dir() { "directory" } else { "file" };
    let mtime = m.modified().ok().map(to_ms).unwrap_or(0.0);
    let ctime = m.created().ok().map(to_ms).unwrap_or(mtime);
    Ok(Json(
        json!({ "type": ty, "size": m.len(), "mtime": mtime, "ctime": ctime }),
    ))
}

// ---- GET /api/fs/readdir ----
async fn readdir(
    State(reg): State<Arc<VaultRegistry>>,
    Query(q): Query<FsQuery>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let p = resolve_q(&reg, &q)?;
    if !std::fs::metadata(&p)?.is_dir() {
        return Err(ApiError::BadRequest("not a directory"));
    }
    let mut out = Vec::new();
    for entry in std::fs::read_dir(&p)? {
        let entry = entry?;
        let ty = if entry.file_type().map(|t| t.is_dir()).unwrap_or(false) {
            "directory"
        } else {
            "file"
        };
        out.push(json!({ "name": entry.file_name().to_string_lossy(), "type": ty }));
    }
    Ok(Json(serde_json::Value::Array(out)))
}

// ---- GET /api/fs/readFile ----
async fn read_file(
    State(reg): State<Arc<VaultRegistry>>,
    Query(q): Query<FsQuery>,
) -> Result<Response, ApiError> {
    let p = resolve_q(&reg, &q)?;
    if std::fs::metadata(&p)?.is_dir() {
        return Err(ApiError::BadRequest("is a directory"));
    }
    let bytes = std::fs::read(&p)?;
    let is_utf8 = matches!(q.encoding.as_deref(), Some("utf8") | Some("utf-8"));
    let ct = if is_utf8 {
        "text/plain; charset=utf-8"
    } else {
        "application/octet-stream"
    };
    Ok(([(CONTENT_TYPE, ct)], bytes).into_response())
}

// ---- POST /api/fs/writeFile ----
#[derive(Deserialize)]
struct WriteBody {
    vault: Option<String>,
    path: String,
    content: String,
    #[serde(default)]
    base64: bool,
}
async fn write_file(
    State(reg): State<Arc<VaultRegistry>>,
    Json(b): Json<WriteBody>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let root = vault_root(&reg, &b.vault)?;
    let p = resolve_in_vault(&root, &b.path)?;
    let bytes = if b.base64 {
        STANDARD
            .decode(b.content.as_bytes())
            .map_err(|_| ApiError::BadRequest("invalid base64"))?
    } else {
        b.content.into_bytes()
    };
    if let Some(parent) = p.parent() {
        std::fs::create_dir_all(parent)?;
    }
    // Honest + durable (dCritiqueCorrectness #3): write the real bytes, fsync, then read
    // the REAL mtime/size back from disk — never synthetic, never acked-before-write.
    let mut f = std::fs::File::create(&p)?;
    f.write_all(&bytes)?;
    f.sync_all()?;
    let meta = f.metadata()?;
    let mtime = meta.modified().ok().map(to_ms).unwrap_or(0.0);
    Ok(Json(
        json!({ "ok": true, "mtime": mtime, "size": meta.len() }),
    ))
}

// ---- POST /api/fs/appendFile ----
#[derive(Deserialize)]
struct AppendBody {
    vault: Option<String>,
    path: String,
    content: String,
}
async fn append_file(
    State(reg): State<Arc<VaultRegistry>>,
    Json(b): Json<AppendBody>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let root = vault_root(&reg, &b.vault)?;
    let p = resolve_in_vault(&root, &b.path)?;
    let mut f = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&p)?;
    f.write_all(b.content.as_bytes())?;
    f.sync_all()?;
    Ok(Json(json!({ "ok": true })))
}

// ---- POST /api/fs/mkdir ----
#[derive(Deserialize)]
struct MkdirBody {
    vault: Option<String>,
    path: String,
    #[serde(default)]
    recursive: bool,
}
async fn mkdir(
    State(reg): State<Arc<VaultRegistry>>,
    Json(b): Json<MkdirBody>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let root = vault_root(&reg, &b.vault)?;
    let p = resolve_in_vault(&root, &b.path)?;
    if b.recursive {
        std::fs::create_dir_all(&p)?;
    } else {
        std::fs::create_dir(&p)?;
    }
    Ok(Json(json!({ "ok": true })))
}

// ---- POST /api/fs/rename ----
#[derive(Deserialize)]
struct RenameBody {
    vault: Option<String>,
    #[serde(rename = "oldPath")]
    old_path: String,
    #[serde(rename = "newPath")]
    new_path: String,
}
async fn rename(
    State(reg): State<Arc<VaultRegistry>>,
    Json(b): Json<RenameBody>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let root = vault_root(&reg, &b.vault)?;
    let from = resolve_in_vault(&root, &b.old_path)?;
    let to = resolve_in_vault(&root, &b.new_path)?;
    if let Some(parent) = to.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::rename(&from, &to)?;
    Ok(Json(json!({ "ok": true })))
}

// ---- POST /api/fs/copyFile ----
#[derive(Deserialize)]
struct CopyBody {
    vault: Option<String>,
    src: String,
    dest: String,
}
async fn copy_file(
    State(reg): State<Arc<VaultRegistry>>,
    Json(b): Json<CopyBody>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let root = vault_root(&reg, &b.vault)?;
    let src = resolve_in_vault(&root, &b.src)?;
    let dest = resolve_in_vault(&root, &b.dest)?;
    if let Some(parent) = dest.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::copy(&src, &dest)?;
    Ok(Json(json!({ "ok": true })))
}

// ---- DELETE /api/fs/unlink ----
async fn unlink(
    State(reg): State<Arc<VaultRegistry>>,
    Query(q): Query<FsQuery>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let p = resolve_q(&reg, &q)?;
    match std::fs::remove_file(&p) {
        Ok(()) => Ok(Json(json!({ "ok": true }))),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(Json(json!({ "ok": true }))),
        Err(e) => Err(e.into()),
    }
}

// ---- DELETE /api/fs/rmdir ----
async fn rmdir(
    State(reg): State<Arc<VaultRegistry>>,
    Query(q): Query<FsQuery>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let p = resolve_q(&reg, &q)?;
    std::fs::remove_dir(&p)?;
    Ok(Json(json!({ "ok": true })))
}

// ---- DELETE /api/fs/rm (recursive optional) ----
async fn rm(
    State(reg): State<Arc<VaultRegistry>>,
    Query(q): Query<FsQuery>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let p = resolve_q(&reg, &q)?;
    let recursive = q.recursive.as_deref() == Some("true");
    let meta = match std::fs::symlink_metadata(&p) {
        Ok(m) => m,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            return Ok(Json(json!({ "ok": true })))
        }
        Err(e) => return Err(e.into()),
    };
    if meta.is_dir() {
        if recursive {
            std::fs::remove_dir_all(&p)?;
        } else {
            std::fs::remove_dir(&p)?;
        }
    } else {
        std::fs::remove_file(&p)?;
    }
    Ok(Json(json!({ "ok": true })))
}

// ---- GET /api/fs/access ----
async fn access(
    State(reg): State<Arc<VaultRegistry>>,
    Query(q): Query<FsQuery>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let p = resolve_q(&reg, &q)?;
    if p.exists() {
        Ok(Json(json!({ "ok": true })))
    } else {
        Err(ApiError::NotFound)
    }
}

// ---- POST /api/fs/utimes ----
#[derive(Deserialize)]
struct UtimesBody {
    vault: Option<String>,
    path: String,
    atime: f64,
    mtime: f64,
}
fn ft_from_ms(ms: f64) -> filetime::FileTime {
    let secs = (ms / 1000.0).floor() as i64;
    let nanos = (((ms / 1000.0) - secs as f64) * 1_000_000_000.0) as u32;
    filetime::FileTime::from_unix_time(secs, nanos)
}
async fn utimes(
    State(reg): State<Arc<VaultRegistry>>,
    Json(b): Json<UtimesBody>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let root = vault_root(&reg, &b.vault)?;
    let p = resolve_in_vault(&root, &b.path)?;
    filetime::set_file_times(&p, ft_from_ms(b.atime), ft_from_ms(b.mtime))?;
    Ok(Json(json!({ "ok": true })))
}

// ---- POST /api/fs/batch-read ----
#[derive(Deserialize)]
struct BatchReadBody {
    vault: Option<String>,
    paths: Vec<String>,
}
async fn batch_read(
    State(reg): State<Arc<VaultRegistry>>,
    Json(b): Json<BatchReadBody>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let root = vault_root(&reg, &b.vault)?;
    let mut files = serde_json::Map::new();
    for rel in b.paths.iter().take(1000) {
        // silently skip anything that escapes the vault or can't be read as utf-8
        if let Ok(p) = resolve_in_vault(&root, rel) {
            if let Ok(s) = std::fs::read_to_string(&p) {
                files.insert(rel.clone(), serde_json::Value::from(s));
            }
        }
    }
    Ok(Json(json!({ "files": files })))
}

/// The fs CRUD routes, to be `.merge`d into the app router (state applied by the caller).
pub fn routes() -> Router<Arc<VaultRegistry>> {
    Router::new()
        .route("/api/fs/stat", get(stat))
        .route("/api/fs/readdir", get(readdir))
        .route("/api/fs/readFile", get(read_file))
        .route("/api/fs/writeFile", post(write_file))
        .route("/api/fs/appendFile", post(append_file))
        .route("/api/fs/mkdir", post(mkdir))
        .route("/api/fs/rename", post(rename))
        .route("/api/fs/copyFile", post(copy_file))
        .route("/api/fs/unlink", delete(unlink))
        .route("/api/fs/rmdir", delete(rmdir))
        .route("/api/fs/rm", delete(rm))
        .route("/api/fs/access", get(access))
        .route("/api/fs/utimes", post(utimes))
        .route("/api/fs/batch-read", post(batch_read))
}

#[cfg(test)]
mod tests {
    use crate::app::app;
    use crate::registry::VaultRegistry;
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use std::fs;
    use std::sync::Arc;
    use tempfile::{tempdir, TempDir};
    use tower::ServiceExt;

    // A registry over one vault "Games" containing a.md (5 bytes) and sub/b.md.
    fn reg() -> (TempDir, Arc<VaultRegistry>) {
        let dir = tempdir().unwrap();
        let v = dir.path().join("Games");
        fs::create_dir(&v).unwrap();
        fs::write(v.join("a.md"), b"hello").unwrap();
        fs::create_dir(v.join("sub")).unwrap();
        fs::write(v.join("sub").join("b.md"), b"world!!").unwrap();
        let reg = Arc::new(VaultRegistry::discover(dir.path()));
        (dir, reg)
    }

    async fn send(reg: &Arc<VaultRegistry>, req: Request<Body>) -> (StatusCode, Vec<u8>) {
        let resp = app(Arc::clone(reg)).oneshot(req).await.unwrap();
        let status = resp.status();
        let bytes = axum::body::to_bytes(resp.into_body(), usize::MAX)
            .await
            .unwrap();
        (status, bytes.to_vec())
    }
    async fn get(reg: &Arc<VaultRegistry>, uri: &str) -> (StatusCode, serde_json::Value) {
        let (s, b) = send(
            reg,
            Request::builder().uri(uri).body(Body::empty()).unwrap(),
        )
        .await;
        (
            s,
            serde_json::from_slice(&b).unwrap_or(serde_json::Value::Null),
        )
    }
    async fn del(reg: &Arc<VaultRegistry>, uri: &str) -> (StatusCode, serde_json::Value) {
        let (s, b) = send(
            reg,
            Request::builder()
                .method("DELETE")
                .uri(uri)
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        (
            s,
            serde_json::from_slice(&b).unwrap_or(serde_json::Value::Null),
        )
    }
    async fn post(
        reg: &Arc<VaultRegistry>,
        uri: &str,
        body: serde_json::Value,
    ) -> (StatusCode, serde_json::Value) {
        let (s, b) = send(
            reg,
            Request::builder()
                .method("POST")
                .uri(uri)
                .header("content-type", "application/json")
                .body(Body::from(body.to_string()))
                .unwrap(),
        )
        .await;
        (
            s,
            serde_json::from_slice(&b).unwrap_or(serde_json::Value::Null),
        )
    }

    #[tokio::test]
    async fn stat_file_and_dir() {
        let (_d, r) = reg();
        let (s, v) = get(&r, "/api/fs/stat?vault=Games&path=a.md").await;
        assert_eq!(s, StatusCode::OK);
        assert_eq!(v["type"], "file");
        assert_eq!(v["size"], 5);
        assert!(v["mtime"].is_number() && v["ctime"].is_number());
        let (_s, v) = get(&r, "/api/fs/stat?vault=Games&path=sub").await;
        assert_eq!(v["type"], "directory");
    }

    #[tokio::test]
    async fn readdir_lists_entries() {
        let (_d, r) = reg();
        let (s, v) = get(&r, "/api/fs/readdir?vault=Games&path=").await;
        assert_eq!(s, StatusCode::OK);
        let names: Vec<&str> = v
            .as_array()
            .unwrap()
            .iter()
            .map(|e| e["name"].as_str().unwrap())
            .collect();
        assert!(names.contains(&"a.md") && names.contains(&"sub"));
        // readdir on a file is a 400
        let (s, _) = get(&r, "/api/fs/readdir?vault=Games&path=a.md").await;
        assert_eq!(s, StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn read_file_utf8_and_dir_error() {
        let (_d, r) = reg();
        let (s, b) = send(
            &r,
            Request::builder()
                .uri("/api/fs/readFile?vault=Games&path=a.md&encoding=utf8")
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        assert_eq!(s, StatusCode::OK);
        assert_eq!(&b, b"hello");
        // a directory is a 400
        let (s, _) = get(&r, "/api/fs/readFile?vault=Games&path=sub").await;
        assert_eq!(s, StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn write_file_round_trips_with_real_metadata() {
        let (_d, r) = reg();
        let (s, v) = post(
            &r,
            "/api/fs/writeFile",
            serde_json::json!({"vault":"Games","path":"sub/new.md","content":"brand new"}),
        )
        .await;
        assert_eq!(s, StatusCode::OK);
        assert_eq!(v["ok"], true);
        assert_eq!(v["size"], 9, "real size of 'brand new'");
        assert!(v["mtime"].is_number());
        // read it back
        let (_s, b) = send(
            &r,
            Request::builder()
                .uri("/api/fs/readFile?vault=Games&path=sub/new.md&encoding=utf8")
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        assert_eq!(&b, b"brand new");
    }

    #[tokio::test]
    async fn write_file_base64() {
        let (_d, r) = reg();
        // "hello" base64
        let (s, _v) = post(
            &r,
            "/api/fs/writeFile",
            serde_json::json!({"vault":"Games","path":"bin.dat","content":"aGVsbG8=","base64":true}),
        )
        .await;
        assert_eq!(s, StatusCode::OK);
        let (_s, b) = send(
            &r,
            Request::builder()
                .uri("/api/fs/readFile?vault=Games&path=bin.dat")
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        assert_eq!(&b, b"hello");
    }

    #[tokio::test]
    async fn append_mkdir_rename_copy() {
        let (_d, r) = reg();
        let (s, _) = post(
            &r,
            "/api/fs/appendFile",
            serde_json::json!({"vault":"Games","path":"a.md","content":" world"}),
        )
        .await;
        assert_eq!(s, StatusCode::OK);
        let (_s, b) = send(
            &r,
            Request::builder()
                .uri("/api/fs/readFile?vault=Games&path=a.md")
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        assert_eq!(&b, b"hello world");

        let (s, _) = post(
            &r,
            "/api/fs/mkdir",
            serde_json::json!({"vault":"Games","path":"x/y/z","recursive":true}),
        )
        .await;
        assert_eq!(s, StatusCode::OK);
        let (s, v) = get(&r, "/api/fs/stat?vault=Games&path=x/y/z").await;
        assert_eq!(s, StatusCode::OK);
        assert_eq!(v["type"], "directory");

        let (s, _) = post(
            &r,
            "/api/fs/rename",
            serde_json::json!({"vault":"Games","oldPath":"a.md","newPath":"renamed.md"}),
        )
        .await;
        assert_eq!(s, StatusCode::OK);
        assert_eq!(
            get(&r, "/api/fs/access?vault=Games&path=renamed.md")
                .await
                .0,
            StatusCode::OK
        );

        let (s, _) = post(
            &r,
            "/api/fs/copyFile",
            serde_json::json!({"vault":"Games","src":"renamed.md","dest":"copy.md"}),
        )
        .await;
        assert_eq!(s, StatusCode::OK);
        assert_eq!(
            get(&r, "/api/fs/access?vault=Games&path=copy.md").await.0,
            StatusCode::OK
        );
    }

    #[tokio::test]
    async fn unlink_rm_and_access() {
        let (_d, r) = reg();
        // access present -> ok; missing -> 404
        assert_eq!(
            get(&r, "/api/fs/access?vault=Games&path=a.md").await.0,
            StatusCode::OK
        );
        assert_eq!(
            get(&r, "/api/fs/access?vault=Games&path=nope.md").await.0,
            StatusCode::NOT_FOUND
        );
        // unlink then idempotent
        assert_eq!(
            del(&r, "/api/fs/unlink?vault=Games&path=a.md").await.0,
            StatusCode::OK
        );
        assert_eq!(
            del(&r, "/api/fs/unlink?vault=Games&path=a.md").await.0,
            StatusCode::OK,
            "unlink is idempotent"
        );
        // rm recursive on the sub dir
        assert_eq!(
            del(&r, "/api/fs/rm?vault=Games&path=sub&recursive=true")
                .await
                .0,
            StatusCode::OK
        );
        assert_eq!(
            get(&r, "/api/fs/access?vault=Games&path=sub").await.0,
            StatusCode::NOT_FOUND
        );
    }

    #[tokio::test]
    async fn batch_read_reads_many_and_skips_missing() {
        let (_d, r) = reg();
        let (s, v) = post(
            &r,
            "/api/fs/batch-read",
            serde_json::json!({"vault":"Games","paths":["a.md","sub/b.md","missing.md"]}),
        )
        .await;
        assert_eq!(s, StatusCode::OK);
        assert_eq!(v["files"]["a.md"], "hello");
        assert_eq!(v["files"]["sub/b.md"], "world!!");
        assert!(
            v["files"].get("missing.md").is_none(),
            "unreadable paths are skipped"
        );
    }

    #[tokio::test]
    async fn utimes_sets_mtime() {
        let (_d, r) = reg();
        // 2001-09-09T01:46:40Z = 1_000_000_000_000 ms
        let (s, _) = post(&r, "/api/fs/utimes", serde_json::json!({"vault":"Games","path":"a.md","atime":1_000_000_000_000i64,"mtime":1_000_000_000_000i64})).await;
        assert_eq!(s, StatusCode::OK);
        let (_s, v) = get(&r, "/api/fs/stat?vault=Games&path=a.md").await;
        let mtime = v["mtime"].as_f64().unwrap();
        assert!(
            (mtime - 1_000_000_000_000.0).abs() < 2000.0,
            "mtime set to ~the requested value, got {mtime}"
        );
    }

    #[tokio::test]
    async fn traversal_is_rejected_on_read_and_write() {
        let (_d, r) = reg();
        let (s, _) = get(&r, "/api/fs/stat?vault=Games&path=../../secret").await;
        assert_eq!(s, StatusCode::BAD_REQUEST, "read traversal rejected");
        let (s, _) = post(
            &r,
            "/api/fs/writeFile",
            serde_json::json!({"vault":"Games","path":"../escape.md","content":"x"}),
        )
        .await;
        assert_eq!(s, StatusCode::BAD_REQUEST, "write traversal rejected");
    }

    #[tokio::test]
    async fn unknown_vault_is_404() {
        let (_d, r) = reg();
        assert_eq!(
            get(&r, "/api/fs/stat?vault=Nope&path=a.md").await.0,
            StatusCode::NOT_FOUND
        );
    }
}
