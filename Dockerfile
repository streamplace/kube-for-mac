FROM alpine:latest

RUN apk update && apk add bash

ADD bin /usr/local/bin

CMD start
