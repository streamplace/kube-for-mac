FROM alpine:latest

RUN apk update && apk add bash jq

ADD bin /usr/local/bin

CMD start
