# Ignite — multi-stage build. The binary lives on the container's fast overlay FS;
# ONLY the vault is bind-mounted at runtime, exactly as Ignis runs (/vaults mount).
# This is what makes the issue004 measurement a faithful end-to-end comparison.

FROM rust:1 AS build
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY examples ./examples
# release builds: the bench harness (for issue004) and the server binary
RUN cargo build --release --example bench && cargo build --release --bin ignite-server

FROM debian:bookworm-slim
COPY --from=build /app/target/release/examples/bench /usr/local/bin/ignite-bench
COPY --from=build /app/target/release/ignite-server /usr/local/bin/ignite-server
# default: benchmark a vault bind-mounted at /vault
ENTRYPOINT ["ignite-bench"]
CMD ["/vault"]
