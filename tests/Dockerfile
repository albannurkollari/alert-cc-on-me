# Lua 5.1 (WoW's language version) with busted and luacheck, for local runs and CI, plus
# bash and yq for scripts/markets.sh.
FROM alpine:3.20
RUN apk add --no-cache lua5.1 lua5.1-dev luarocks5.1 build-base curl unzip bash yq-go \
	&& luarocks-5.1 install busted 2.2.0-1 \
	&& luarocks-5.1 install luacheck 1.2.0-1
WORKDIR /src
