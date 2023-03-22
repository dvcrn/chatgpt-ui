FROM elixir:1.14.3-alpine AS build

# install build dependencies
RUN apk add --no-cache build-base git python3 curl npm

# sets work dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV="prod"

COPY . .
RUN npm i -g yarn && yarn
RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile
RUN mix assets.deploy
RUN mix compile
RUN mix release

# app stage
FROM alpine:3.17 AS app

ENV MIX_ENV="prod"

# install runtime dependencies
RUN apk add --no-cache libstdc++ openssl ncurses-libs

ENV USER="elixir"

WORKDIR "/home/${USER}/app"

# Create unprivileged user to run the release
RUN \
    addgroup \
    -g 1000 \
    -S "${USER}" \
    && adduser \
    -s /bin/sh \
    -u 1000 \
    -G "${USER}" \
    -h "/home/${USER}" \
    -D "${USER}" \
    && su "${USER}"

# run as user
USER "${USER}"

# copy release executables
COPY --from=build --chown="${USER}":"${USER}" /app/_build/"${MIX_ENV}"/rel/chatgpt ./

ENTRYPOINT ["bin/chatgpt"]

CMD ["start"]
