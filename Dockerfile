FROM lukemathwalker/cargo-chef:latest-rust-slim-bookworm AS chef
WORKDIR app

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path "recipe.json"

FROM chef AS builder

ARG cargo_arch
ENV target="$cargo_arch-unknown-linux-gnu"

RUN apt update && apt upgrade --assume-yes && \
    apt install --assume-yes -- "build-essential" && \
    apt autoremove --assume-yes && apt clean all

COPY --from=planner "/app/recipe.json" "recipe.json"
RUN cargo chef cook --release --target "${target}" --recipe-path "recipe.json"

COPY . .
RUN cargo build --release --target "${target}" --bin "atuin"

FROM debian:bookworm-slim AS runtime

RUN useradd -c "atuin user" atuin && \
    mkdir "/config" && chown "atuin:atuin" "/config"
RUN apt update && apt upgrade --assume-yes && \
    apt install --assume-yes -- "ca-certificates" "curl" && \
    apt autoremove --assume-yes && apt clean all && rm -rf "/var/lib/apt/lists/"*
WORKDIR app

USER atuin

ARG cargo_arch
ENV target "$cargo_arch-unknown-linux-gnu"
ENV TZ="Etc/UTC"
ENV RUST_LOG="atuin::api=info"
ENV ATUIN_CONFIG_DIR="/config"

COPY --from=builder "/app/target/${target}/release/atuin" "/usr/local/bin"
ENTRYPOINT ["/usr/local/bin/atuin"]
CMD ["server", "start"]
