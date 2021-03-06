#
# Cartodb container
#
FROM ubuntu:16.04
MAINTAINER Stefan Verhoeven <s.verhoeven@esciencecenter.nl>

# Configuring locales
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y -q apt-utils && apt-get install -y -q locales && dpkg-reconfigure locales && \
      locale-gen en_US.UTF-8 && \
      update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN useradd -m -d /home/cartodb -s /bin/bash cartodb && \
  apt-get install -y -q \
    build-essential \
    autoconf \
    automake \
    libtool \
    checkinstall \
    unp \
    zip \
    unzip \
    git-core \
    git \
    subversion \
    curl \
    libgeos-c1v5 \
    libgeos-dev \
    libjson0 \
    python-simplejson \
    libjson0-dev \
    proj-bin \
    proj-data \
    libproj-dev \
    gdal-bin \
    libgdal1-dev \
    libgdal-dev \
    postgresql-9.5 \
    postgresql-client-9.5 \
    postgresql-contrib-9.5 \
    postgresql-server-dev-9.5 \
    postgresql-plpython-9.5 \
    postgresql-9.5-plproxy \
    postgresql-9.5-postgis-2.2 \
    postgresql-9.5-postgis-scripts \
    postgis \
    liblwgeom-2.2-5 \
    ca-certificates \
    redis-server \
    python2.7-dev \
    python-setuptools \
    imagemagick \
    libmapnik-dev \
    mapnik-utils \
    python-mapnik \
    python-argparse \
    python-gdal \
    python-chardet \
    python-pip \
    python-all-dev \
    python-docutils \
    openssl \
    libreadline6 \
    zlib1g \
    zlib1g-dev \
    libssl-dev \
    libyaml-dev \
    libsqlite3-dev \
    sqlite3 \
    libxml2-dev \
    libxslt-dev \
    libc6-dev \
    ncurses-dev \
    bison \
    pkg-config \
    libpq5 \
    libpq-dev \
    libcurl4-gnutls-dev \
    libffi-dev \
    libgdbm-dev \
    gnupg \
    libreadline6-dev \
    libcairo2-dev \
    libjpeg8-dev \
    libpango1.0-dev \
    libgif-dev \
    libgmp-dev \
    libicu-dev \
    wget \
    nginx-light \
    net-tools \
  --no-install-recommends && \
  rm -rf /var/lib/apt/lists/*

RUN git config --global user.email you@example.com
RUN git config --global user.name "Your Name"

# Varnish 3, Ubuntu:16.04 comes with Varnish 4.1 which can't be run with anonymous admin telnet
RUN cd /opt && \
    wget https://repo.varnish-cache.org/source/varnish-3.0.7.tar.gz && \
    tar -zxf varnish-3.0.7.tar.gz && \
    cd varnish-3.0.7 && \
    ./configure --prefix=/opt/varnish && \
    make && \
    make install && \
    cd /opt && \
    rm -rf varnish-3.0.7 varnish-3.0.7.tar.gz

# ogr2ogr2 static build, see https://github.com/CartoDB/cartodb/wiki/How-to-build-gdal-and-ogr2ogr2
# using cartodb instruction got error https://trac.osgeo.org/gdal/ticket/6073
# https://github.com/OSGeo/gdal/compare/trunk...CartoDB:ogr2ogr2 has no code changes, so just use latest gdal tarball
RUN cd /opt && \
    curl http://download.osgeo.org/gdal/2.1.1/gdal-2.1.1.tar.gz -o gdal-2.1.1.tar.gz && \
    tar -zxf gdal-2.1.1.tar.gz && \
    cd gdal-2.1.1 && \
    ./configure --disable-shared && \
    make -j 4 && \
    cp apps/ogr2ogr /usr/bin/ogr2ogr2 && \
    cd /opt && \
    rm -rf /opt/ogr2ogr2 /opt/gdal-2.1.1.tar.gz /root/.gitconfig /opt/gdal-2.1.1

# Install NodeJS
RUN curl https://nodejs.org/download/release/v6.9.2/node-v6.9.2-linux-x64.tar.gz| tar -zxf - --strip-components=1 -C /usr && \
  npm install -g grunt-cli && \
  npm install -g npm@3.10.9 && \
  rm -r /tmp/npm-* /root/.npm

# Install rvm
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3 && \
    curl -sSL https://raw.githubusercontent.com/wayneeseguin/rvm/stable/binscripts/rvm-installer | bash -s stable --ruby && \
    echo 'source /usr/local/rvm/scripts/rvm' >> /etc/bash.bashrc && \
    /bin/bash -l -c rvm requirements
ENV PATH /usr/local/rvm/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN echo rvm_max_time_flag=15 >> ~/.rvmrc && \
    /bin/bash -l -c 'rvm install 2.2.3' && \
    /bin/bash -l -c 'rvm use 2.2.3 --default' && \
    /bin/bash -l -c 'gem install bundle archive-tar-minitar' && \
    /bin/bash -l -c 'gem install bundler compass --no-doc --no-ri' && \
    rm -rf /usr/local/rvm/src

# Setting PostgreSQL
RUN sed -i 's/\(peer\|md5\)/trust/' /etc/postgresql/9.5/main/pg_hba.conf && \
    service postgresql start && \
    createuser publicuser --no-createrole --no-createdb --no-superuser -U postgres && \
    createuser tileuser --no-createrole --no-createdb --no-superuser -U postgres && \
    service postgresql stop

# Crankshaft: CARTO Spatial Analysis extension for PostgreSQL
RUN cd / && \
    git clone https://github.com/CartoDB/crankshaft.git && \
    cd /crankshaft && \
    git checkout master && \
    make install && \
    cd ..

# Initialize template postgis db
ADD ./template_postgis.sh /tmp/template_postgis.sh
RUN service postgresql start && /bin/su postgres -c \
      /tmp/template_postgis.sh && service postgresql stop

# Install cartodb extension
RUN git clone https://github.com/CartoDB/cartodb-postgresql && \
      cd cartodb-postgresql && \
      git checkout master && \
      PGUSER=postgres make install
ADD ./cartodb_pgsql.sh /tmp/cartodb_pgsql.sh
RUN service postgresql start && /bin/su postgres -c \
      /tmp/cartodb_pgsql.sh && service postgresql stop

# Install CartoDB API
RUN git clone git://github.com/CartoDB/CartoDB-SQL-API.git && \
    cd CartoDB-SQL-API && \
    npm install && \
    rm -r /tmp/npm-* /root/.npm

# Install Windshaft
RUN git clone git://github.com/CartoDB/Windshaft-cartodb.git && \
    cd Windshaft-cartodb && \
    git checkout master && \
    npm install && \
    rm -r /tmp/npm-* /root/.npm && \
    mkdir logs

# Install CartoDB
RUN git clone --recursive git://github.com/CartoDB/cartodb.git && \
    cd cartodb && \
    git checkout master && \
    npm install && \
    rm -r /tmp/npm-* /root/.npm && \
    perl -pi -e 's/gdal==1\.10\.0/gdal==1.11.3/' python_requirements.txt && \
    pip install --no-use-wheel -r python_requirements.txt && \
    /bin/bash -l -c 'bundle install' && \
    /bin/bash -l -c 'bundle exec grunt --environment development' && \
    rm -rf .git /root/.cache/pip node_modules

# Geocoder SQL client + server
RUN git clone https://github.com/CartoDB/data-services && \
  cd /data-services/geocoder/extension && PGUSER=postgres make all install && cd / && \
  git clone https://github.com/CartoDB/dataservices-api.git && \
  ln -s /usr/local/rvm/rubies/ruby-2.2.3/bin/ruby /usr/bin && \
  cd /dataservices-api/server/extension && PGUSER=postgres make install && \
  cd ../lib/python/cartodb_services && python setup.py install && \
  cd ../../../../client && PGUSER=postgres make install && \
  service postgresql start && \
  echo "CREATE ROLE geocoder WITH LOGIN SUPERUSER PASSWORD 'geocoder'" | psql -U postgres postgres && \
  createdb -U postgres -E UTF8 -O geocoder geocoder && \
  echo 'CREATE EXTENSION plpythonu;CREATE EXTENSION postgis;CREATE EXTENSION cartodb;CREATE EXTENSION cdb_geocoder;CREATE EXTENSION plproxy;CREATE EXTENSION cdb_dataservices_server;CREATE EXTENSION cdb_dataservices_client;' | psql -U geocoder geocoder && \
  service postgresql stop

# Copy confs
ADD ./config/CartoDB-dev.js \
      /CartoDB-SQL-API/config/environments/development.js
ADD ./config/WS-dev.js \
      /Windshaft-cartodb/config/environments/development.js
ADD ./config/app_config.yml /cartodb/config/app_config.yml
ADD ./config/database.yml /cartodb/config/database.yml
ADD ./create_dev_user /cartodb/script/create_dev_user
ADD ./setup_organization.sh /cartodb/script/setup_organization.sh
ADD ./config/cartodb.nginx.proxy.conf /etc/nginx/sites-enabled/default
ADD ./config/varnish.vcl /etc/varnish.vcl
ENV PATH /usr/local/rvm/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN mkdir -p /cartodb/log && touch /cartodb/log/users_modifications && \
    /opt/varnish/sbin/varnishd -a :6081 -T localhost:6082 -s malloc,256m -f /etc/varnish.vcl && \
    service postgresql start && service redis-server start && \
	bash -l -c "cd /cartodb && bash script/create_dev_user || bash script/create_dev_user && \
    bash script/setup_organization.sh" && \
	service postgresql stop && service redis-server stop

EXPOSE 80

ENV GDAL_DATA /usr/share/gdal/1.11

ADD ./startup.sh /opt/startup.sh

CMD ["/bin/bash", "/opt/startup.sh"]
