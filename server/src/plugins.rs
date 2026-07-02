//! Server-plugin seam (dPlugins) + the WS channel hub.
//!
//! Ignite reimplements Ignis's Node plugin system natively. `ServerPlugin` is the minimal
//! extensibility seam (only headless-sync implements it today). `ChannelHub` is the Rust
//! analog of Ignis's `wss.channel(name).broadcastToVault(vault, msg)`: a plugin publishes a
//! channel-scoped, vault-scoped message and every `/ws` client that subscribed to that channel
//! (via `subscribe-channel`) and is connected to that vault receives it.

use tokio::sync::broadcast;

/// Human-facing plugin metadata for `GET /api/plugins`.
#[derive(Debug, Clone, serde::Serialize)]
pub struct PluginDescriptor {
    pub id: String,
    pub name: String,
    pub description: String,
}

/// The extensibility seam. Concrete plugins (headless-sync) are wired into the router in
/// `app.rs`; this trait documents the contract and drives the `/api/plugins` listing.
pub trait ServerPlugin: Send + Sync {
    fn descriptor(&self) -> PluginDescriptor;
}

/// One channel-scoped, vault-scoped broadcast message. `json` is the fully-formed wire
/// object (`{channel, type, payload}`) the client receives.
#[derive(Debug, Clone)]
pub struct ChannelMsg {
    pub channel: String,
    pub vault: String,
    pub json: String,
}

/// A single broadcast bus shared by the whole server. `/ws` connections subscribe once and
/// filter by (subscribed channel set × their vault); plugins publish via [`ChannelHub::broadcast`].
#[derive(Clone)]
pub struct ChannelHub {
    tx: broadcast::Sender<ChannelMsg>,
}

impl Default for ChannelHub {
    fn default() -> Self {
        Self::new()
    }
}

impl ChannelHub {
    pub fn new() -> Self {
        let (tx, _) = broadcast::channel(1024);
        Self { tx }
    }

    pub fn subscribe(&self) -> broadcast::Receiver<ChannelMsg> {
        self.tx.subscribe()
    }

    /// Publish `{channel, type, payload}` to `vault`'s subscribers on `channel`.
    /// `payload` is any serializable value; `msg_type` is e.g. "sync-status".
    pub fn broadcast<T: serde::Serialize>(
        &self,
        channel: &str,
        vault: &str,
        msg_type: &str,
        payload: T,
    ) {
        let wire = serde_json::json!({ "channel": channel, "type": msg_type, "payload": payload });
        let _ = self.tx.send(ChannelMsg {
            channel: channel.to_string(),
            vault: vault.to_string(),
            json: wire.to_string(),
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn hub_delivers_channel_scoped_messages() {
        let hub = ChannelHub::new();
        let mut rx = hub.subscribe();
        hub.broadcast("plugin:headless-sync", "Games", "sync-status", serde_json::json!({"ok":true}));
        let msg = rx.recv().await.unwrap();
        assert_eq!(msg.channel, "plugin:headless-sync");
        assert_eq!(msg.vault, "Games");
        let v: serde_json::Value = serde_json::from_str(&msg.json).unwrap();
        assert_eq!(v["channel"], "plugin:headless-sync");
        assert_eq!(v["type"], "sync-status");
        assert_eq!(v["payload"]["ok"], true);
    }
}
