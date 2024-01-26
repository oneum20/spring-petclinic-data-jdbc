FROM openjdk:17-alpine
LABEL maintainer="github.com/oneum20"

ARG USER=app
ARG GROUP=app
ARG WORKDIR=/app
ARG LOGDIR=$WORKDIR/log

RUN addgroup -S $GROUP &&\
    adduser --system -G $GROUP -u 999 $USER &&\
    mkdir $WORKDIR $LOGDIR &&\
    chown -R $USER:$GROUP $WORKDIR

USER $USER
WORKDIR $WORKDIR

COPY --chown=$USER:$GROUP build/libs/app.jar .

ENTRYPOINT java -jar app.jar
