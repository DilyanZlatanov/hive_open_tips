# Initiate a container to build the application in
FROM phusion/baseimage:focal-1.2.0

# Install needed packages
ENV LANG=en_US.UTF-8

RUN apt-get update
RUN apt-get install -y \
    language-pack-en \
    sudo \
    wget \
    xz-utils \
    gnupg \
    gnupg2 \
    gnupg1 

# Add repository and install Postgres 14
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN apt-get update -y
RUN apt-get install -y postgresql-14

RUN apt-get clean && rm -r /var/lib/apt/lists/*

WORKDIR /usr/src/app

# Install postgREST
RUN wget  https://github.com/PostgREST/postgrest/releases/download/v10.1.2/postgrest-v10.1.2-linux-static-x64.tar.xz

RUN tar xJf postgrest-v10.1.2-linux-static-x64.tar.xz
RUN sudo mv 'postgrest' '/usr/local/bin/postgrest'
RUN rm postgrest-v10.1.2-linux-static-x64.tar.xz

# Install pg_timetable
RUN wget https://github.com/cybertec-postgresql/pg_timetable/releases/download/v5.6.0/pg_timetable_Linux_x86_64.deb
RUN sudo apt-get install ./pg_timetable_Linux_x86_64.deb

# Copy the application source into the container and ensure entrypoint is executable
COPY . .
RUN chmod +x docker_entrypoint.sh

# Create OS user to be used for postgREST authentication using local UNIX socket and the Postgres peer auth method
RUN useradd -ms /bin/bash postgrest_auth
# Create similar user to be used for pg_timetable authentication
RUN useradd -ms /bin/bash scheduler

# Run the application
ENTRYPOINT [ "/usr/src/app/docker_entrypoint.sh" ]
