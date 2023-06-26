FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && \
    apt-get install -y \
        build-essential \
        python3 python3-dev python3-pip \
        libexpat1 apache2 apache2-utils ssl-cert \
        libapache2-mod-wsgi-py3 \
        libmysqlclient-dev \
        mysql-client \
        mysql-server \
    && \
    pip3 install markdown \
    && \
    ln -s /usr/bin/python3 /usr/bin/python

ARG emdrosversion="3.7.3"
ARG emdrosdir="/opt/emdros"

WORKDIR build

COPY /src/software/emdros-${emdrosversion}.tar.gz .
RUN tar xf emdros-${emdrosversion}.tar.gz

WORKDIR emdros-${emdrosversion}
RUN ./configure \
    --prefix=${emdrosdir} \
    --with-sqlite3=no \
    --with-mysql=yes \
    --with-swig-language-java=no \
    --with-swig-language-python2=no \
    --with-swig-language-python3=yes \
    --with-postgresql=no \
    --with-wx=no \
    --with-swig-language-csharp=no \
    --with-swig-language-php7=no \
    --with-bpt=no \
    --disable-debug && \
    make && \
    make install

ENTRYPOINT bash
