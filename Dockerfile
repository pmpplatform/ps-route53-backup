FROM library/golang:1.14-alpine AS build

ENV CLI53_VERSION 0.8.17
RUN apk add --no-cache --update --virtual .build-deps git make \
  && git clone https://github.com/barnybug/cli53.git /go/src/github.com/barnybug/cli53 \
  && cd /go/src/github.com/barnybug/cli53 \
  && git checkout ${CLI53_VERSION} \
  && make build \
  && apk del .build-deps


FROM library/alpine:3.11.5
LABEL maintainer "Chad Jones <cj@patientsky.com>"

COPY --from=build /go/src/github.com/barnybug/cli53/cli53 /usr/bin/cli53

RUN apk add --update --no-cache \
  openssl \
  openssh-client \
  bash \
  git \
  ca-certificates \
  jq \
  git-crypt \
  tzdata

RUN adduser -h /backup -D backup && mkdir -p /opt && chown backup:backup /opt

ENV PATH="/:/opt/:${PATH}"

COPY entrypoint.sh /
USER backup
ENTRYPOINT ["/entrypoint.sh"]