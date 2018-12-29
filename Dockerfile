FROM alpine:latest

MAINTAINER T.N.N <nissi.tafie@gmail.com>

ARG user=jenkins
ARG group=jenkins
ARG uid=10000
ARG gid=10000

ENV GRADLE_VERSION 4.9
ENV GRADLE_HOME /usr/local/gradle
ENV PATH ${PATH}:${GRADLE_HOME}/bin
ENV GRADLE_USER_HOME /gradle

RUN apk update && apk add libstdc++ && rm -rf /var/cache/apk/*

##################
ENV LANG C.UTF-8

RUN { \
		echo '#!/bin/sh'; \
		echo 'set -e'; \
		echo; \
		echo 'dirname "$(dirname "$(readlink -f "$(which javac || which java)")")"'; \
	} > /usr/local/bin/docker-java-home \
	&& chmod +x /usr/local/bin/docker-java-home
ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk
ENV PATH $PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin

ENV JAVA_VERSION 8u181
ENV JAVA_ALPINE_VERSION 8.181.13-r0

RUN set -x \
	&& apk add --no-cache \
		openjdk8="$JAVA_ALPINE_VERSION" \
	&& [ "$JAVA_HOME" = "$(docker-java-home)" ]
##################

RUN   apk update \                                                                                                                                                                                                                        
  &&   apk add ca-certificates wget \                                                                                                                                                                                                      
  &&   update-ca-certificates  

RUN apk add bash

RUN apk add --no-cache curl

RUN apk add --no-cache wget

# Install gradle
WORKDIR /usr/local

RUN curl -skL -o /tmp/gradle-bin.zip https://services.gradle.org/distributions/gradle-$GRADLE_VERSION-bin.zip && \
    mkdir -p /opt/gradle && \
    unzip -q /tmp/gradle-bin.zip -d /opt/gradle && \
    ln -sf /opt/gradle/gradle-$GRADLE_VERSION/bin/gradle /usr/local/bin/gradle

ENV HOME /home/${user}

WORKDIR /home/${user}
RUN chown -R 10000:0 /home/${user} && \
    chmod -R g+rw /home/${user}

RUN apk add --no-cache openrc \
    && rm -rf "/tmp/"* \
    && echo 'rc_provide="loopback net"' >> /etc/rc.conf \
    && sed -i -e 's/#rc_sys=""/rc_sys="lxc"/g' -e 's/^#\(rc_logger="YES"\)$/\1/' /etc/rc.conf \
    && sed -i '/tty/d' /etc/inittab \
    && sed -i 's/hostname $opts/# hostname $opts/g' /etc/init.d/hostname \
    && sed -i 's/mount -t tmpfs/# mount -t tmpfs/g' /lib/rc/sh/init.sh

RUN apk update \
    && apk add alpine-sdk bash gcc git libffi-dev musl-dev perl python3 python3-dev sshpass openssh libressl-dev \
    && pip3 install --upgrade pip \
    && pip3 install ansible

############### KUBECTL ##############
# Metadata
LABEL org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/lachie83/k8s-kubectl" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.docker.dockerfile="/Dockerfile"

ENV KUBE_LATEST_VERSION="v1.13.1"

RUN apk add --update ca-certificates \
 && apk add --update -t deps curl \
 && curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
 && chmod +x /usr/local/bin/kubectl \
 && apk del --purge deps \
 && rm /var/cache/apk/*
 ####################################

RUN apk add docker

RUN pip3 install docker-compose

RUN rc-update add docker boot

RUN mkdir -p /gradle && mkdir -p /app

RUN adduser -u 10000 -D -G root -g 'Linux User named' -s /sbin/nologin -D jenkins

VOLUME /var/run/docker.sock:/var/run/docker.sock

ADD entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod 777 /usr/local/bin/entrypoint.sh

USER root

ENTRYPOINT ["sh", "/usr/local/bin/entrypoint.sh"]