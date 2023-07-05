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
        unzip \
    && \
    pip3 install markdown \
    && \
    ln -s /usr/bin/python3 /usr/bin/python

# Compile and install EMDROS software

ARG emdrosversion="3.7.3"
ARG emdrosdir="/opt/emdros"

WORKDIR /app
COPY src/emdros .
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

# Configure Apache

WORKDIR /etc/apache2
COPY src/apache/wsgi.conf mods-available 
COPY src/apache/shebanq.conf sites-available 
RUN ln -sf ../mods-available/expires.load mods-enabled \
    && \
    ln -sf ../mods-available/headers.load mods-enabled \
    && \
    ln -sf ../sites-available/shebanq.conf sites-enabled/shebanq.conf

WORKDIR /app
