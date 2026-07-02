//! The `/ws` WebSocket endpoint — streams a vault's live change events to clients,
//! wire-compatible with Ignis c9656b8 (`{type, path, stat?}`). Applies dCritiqueEfficiency
//! #5: each event is serialized ONCE by the watcher (see `index::apply_paths`) and broadcast;
//! this handler honors backpressure (a lagging client recovers, never buffers unboundedly).

use crate::plugins::{ChannelHub, ChannelMsg};
use crate::registry::VaultRegistry;
use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Extension, Query, State};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use futures_util::{SinkExt, StreamExt};
use serde::Deserialize;
use std::collections::HashSet;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::broadcast::error::RecvError;
use tokio::sync::broadcast::Receiver;

const HEARTBEAT: Duration = Duration::from_secs(30);

#[derive(Deserialize)]
pub struct WsQuery {
    pub vault: Option<String>,
}

/// GET /ws?vault=<name> — upgrade to a WebSocket and stream the vault's live change events.
/// 400 if `vault` is missing, 404 if unknown — both rejected BEFORE the upgrade.
pub async fn ws_handler(
    ws: WebSocketUpgrade,
    Query(q): Query<WsQuery>,
    State(reg): State<Arc<VaultRegistry>>,
    Extension(hub): Extension<ChannelHub>,
) -> Response {
    let Some(vault) = q.vault else {
        return StatusCode::BAD_REQUEST.into_response();
    };
    let Some(index) = reg.get(&vault) else {
        return StatusCode::NOT_FOUND.into_response();
    };
    let rx = index.subscribe();
    let chan_rx = hub.subscribe();
    ws.on_upgrade(move |socket| serve_socket(socket, rx, chan_rx, vault))
}

async fn serve_socket(
    socket: WebSocket,
    mut rx: Receiver<String>,
    mut chan_rx: Receiver<ChannelMsg>,
    vault: String,
) {
    let (mut tx, mut incoming) = socket.split();
    let mut heartbeat = tokio::time::interval(HEARTBEAT);
    heartbeat.tick().await; // consume the immediate first tick (don't ping instantly)
    let mut channels: HashSet<String> = HashSet::new();

    loop {
        tokio::select! {
            // a vault change event -> client (already serialized once by the watcher)
            event = rx.recv() => match event {
                Ok(text) => {
                    if tx.send(Message::Text(text.into())).await.is_err() {
                        break; // client gone
                    }
                }
                Err(RecvError::Lagged(_)) => continue, // dropped oldest; stay connected
                Err(RecvError::Closed) => break,
            },
            // a plugin channel broadcast -> client, if subscribed to that channel + this vault
            cmsg = chan_rx.recv() => match cmsg {
                Ok(m) => {
                    if m.vault == vault && channels.contains(&m.channel)
                        && tx.send(Message::Text(m.json.into())).await.is_err()
                    {
                        break;
                    }
                }
                Err(RecvError::Lagged(_)) => continue,
                Err(RecvError::Closed) => {} // hub gone; keep serving file events
            },
            // client -> server control messages
            msg = incoming.next() => match msg {
                Some(Ok(Message::Text(t))) => handle_control(t.as_str(), &mut channels),
                Some(Ok(Message::Close(_))) | None => break,
                Some(Ok(_)) => {} // Ping is auto-ponged by axum; Pong/Binary ignored
                Some(Err(_)) => break,
            },
            // periodic keep-alive ping
            _ = heartbeat.tick() => {
                if tx.send(Message::Ping(Vec::new().into())).await.is_err() {
                    break;
                }
            }
        }
    }
}

/// Track channel subscriptions (`subscribe-channel` / `unsubscribe-channel`). The set is
/// read in the channel-broadcast select branch to decide which plugin messages to forward.
fn handle_control(text: &str, channels: &mut HashSet<String>) {
    let Ok(v) = serde_json::from_str::<serde_json::Value>(text) else {
        return;
    };
    match v.get("type").and_then(|t| t.as_str()) {
        Some("subscribe-channel") => {
            if let Some(c) = v.get("channel").and_then(|c| c.as_str()) {
                channels.insert(c.to_string());
            }
        }
        Some("unsubscribe-channel") => {
            if let Some(c) = v.get("channel").and_then(|c| c.as_str()) {
                channels.remove(c);
            }
        }
        _ => {} // tolerate unknown / plugin messages
    }
}
