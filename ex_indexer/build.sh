#!/bin/bash

export CONTAINER_RUNTIME="podman"
if ! command -v podman &> /dev/null
then
    export CONTAINER_RUNTIME="docker"
fi

#build the ordd
$CONTAINER_RUNTIME build --tag elixir_builder -f build.docker .
$CONTAINER_RUNTIME run -it --rm -v .:/root/ord --entrypoint bash elixir_builder -c "echo 'building ordd..' \
    && cd /root/ord \
    && export MIX_ENV=prod \
    && rm -rf _build \
    && mix deps.get \
    && mix release \
    && cp _build/prod/rel/bakeware/ord ordd"
sha256sum ordd