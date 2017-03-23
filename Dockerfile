FROM alpine:latest

RUN apk update && apk add bash
ADD run.sh /run.sh
ADD common.sh /common.sh

CMD /run.sh
