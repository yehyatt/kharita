# tippecanoe (BSD-2) for building the Overture places tile layer.
FROM debian:12-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential libsqlite3-dev zlib1g-dev git ca-certificates \
 && git clone --depth 1 --branch 2.79.0 https://github.com/felt/tippecanoe /src && make -C /src -j4
FROM debian:12-slim
RUN apt-get update && apt-get install -y --no-install-recommends libsqlite3-0 zlib1g && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/tippecanoe /src/tile-join /usr/local/bin/
ENTRYPOINT ["tippecanoe"]
