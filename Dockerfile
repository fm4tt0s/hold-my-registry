FROM alpine

LABEL version="0.1"
LABEL author="felipe mattos"
LABEL email="<fmattos@gmx.com>"

RUN apk update && \
  apk add --no-cache openssl && \
  rm -rf /var/cache/apk/*

ENTRYPOINT ["openssl"]
