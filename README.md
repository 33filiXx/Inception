*This project has been created as part of the 42 curriculum by wel-mjiy.*

# Docker Learning Guide — From Zero to Inception

This README is both:

1. A documentation of what I learned while studying Docker for the 42 **Inception** project.
2. A beginner-friendly guide for someone who wants to understand Docker from the ground up.

The goal is not only to memorize Docker commands, but to understand **what Docker is doing underneath**.

---

# 1. What is Docker?

Docker is a platform used to build, package, run, and manage applications inside isolated environments called **containers**.

A container is not a virtual machine.

A container is mainly:

> A normal Linux process running with isolation around it.

Linux provides most of that isolation using:

- Namespaces
- Cgroups
- Mounts
- Linux capabilities
- Filesystem layers

A very simple mental model:

```text
Application
    ↓
Container
    ↓
Docker
    ↓
Linux kernel
```

---

# 2. Dockerfile → Image → Container

The basic Docker lifecycle is:

```text
Dockerfile
    ↓
docker build
    ↓
Image
    ↓
docker run
    ↓
Container
    ↓
Application process
```

## Dockerfile

A `Dockerfile` is a recipe that explains how to build an image.

Example:

```dockerfile
FROM debian:bookworm

RUN apt update && apt install -y nginx

COPY nginx.conf /etc/nginx/nginx.conf

CMD ["nginx", "-g", "daemon off;"]
```

## Image

An image is a read-only template containing:

- Filesystem
- Installed programs
- Libraries
- Configuration files
- Metadata

The image itself is not running.

## Container

A container is a running instance of an image.

One image can create many containers:

```text
           Image
        /    |    \
       ↓     ↓     ↓
Container Container Container
    A        B        C
```

Each container gets its own writable layer.

---

# 3. How a Docker Image is Built

When we run:

```bash
docker build -t myimage .
```

Docker reads the Dockerfile from top to bottom.

Example:

```dockerfile
FROM debian:bookworm
RUN apt update
RUN apt install -y nginx
COPY nginx.conf /etc/nginx/nginx.conf
CMD ["nginx", "-g", "daemon off;"]
```

Conceptually:

```text
FROM
 ↓
use Debian base image layers

RUN apt update
 ↓
run command in temporary build environment
 ↓
save filesystem changes as a new layer

RUN apt install nginx
 ↓
run command
 ↓
save changes as another layer

COPY
 ↓
add file to image filesystem

CMD
 ↓
save runtime metadata
```

The result is an image made of layers.

---

# 4. Docker BuildKit

BuildKit is Docker's modern image builder.

When we use:

```bash
docker build .
```

the simplified flow is:

```text
Docker CLI
    ↓
dockerd
    ↓
BuildKit
    ↓
Dockerfile
    ↓
image layers
    ↓
final image
```

BuildKit handles things such as:

- Dockerfile instructions
- Build cache
- Parallel build steps
- Multi-stage builds
- Build secrets
- Image layer creation

Important:

```text
docker build
→ BuildKit is involved

docker run
→ BuildKit is normally not involved
```

---

# 5. Image Layers and OverlayFS

Docker images are made of filesystem layers.

Example:

```text
Layer 3 → nginx.conf
Layer 2 → nginx installed
Layer 1 → Debian filesystem
```

Linux can combine those layers and present them as one filesystem.

A common filesystem mechanism used by Docker on Linux is **OverlayFS**.

OverlayFS uses concepts such as:

```text
lowerdir
→ read-only lower layers

upperdir
→ writable layer

merged
→ final combined view

workdir
→ internal OverlayFS work area
```

When a container starts:

```text
Writable container layer
────────────────────────
Image layer 3
────────────────────────
Image layer 2
────────────────────────
Image layer 1
```

The container sees all of them as one filesystem.

## Copy-up

If a container modifies a file from a read-only image layer, OverlayFS copies that file into the writable layer first.

This is called:

```text
copy-up
```

## Deleting files

A lower read-only layer cannot really be modified.

If a container deletes a lower-layer file, OverlayFS can create a special marker that hides it from the merged view.

This is commonly called a:

```text
whiteout
```

---

# 6. Docker Runtime Stack

When we run:

```bash
docker run nginx
```

a simplified runtime flow is:

```text
Docker CLI
    ↓
dockerd
    ↓
containerd
    ↓
containerd-shim
    ↓
runc
    ↓
Linux kernel
    ↓
container process
```

## Docker CLI

This is the command we use:

```bash
docker run
docker build
docker ps
docker images
```

The CLI sends requests to the Docker daemon.

## dockerd

`dockerd` is the Docker daemon.

It understands Docker-level concepts such as:

- Images
- Containers
- Networks
- Volumes
- Port publishing
- Restart policies
- Docker configuration

## containerd

`containerd` manages lower-level container lifecycle tasks.

It deals with things like:

- Container tasks
- Image content
- Root filesystem preparation
- Snapshots
- Runtime management

## containerd-shim

The shim stays close to the running container process.

It helps manage:

- Standard input/output/error
- Exit status
- Signals
- Process lifecycle communication

`runc` normally does not stay running for the entire container lifetime.

## runc

`runc` is the low-level OCI runtime.

Its job is to create the Linux isolation and start the process.

Conceptually:

```text
runc
 ↓
Linux kernel
 ↓
create namespaces
configure cgroups
configure mounts
configure capabilities
start process
```

After the container process has started, `runc` normally exits.

---

# 7. OCI

OCI stands for:

> Open Container Initiative

OCI defines standards used by the container ecosystem.

Important OCI specifications include:

```text
OCI Image Specification
→ how container images are structured

OCI Runtime Specification
→ how a runtime should create and manage containers

OCI Distribution Specification
→ how images are distributed through registries
```

The OCI Runtime Specification is not mainly a communication protocol.

It defines a standard description of a container runtime configuration.

For example:

```text
process
root filesystem
mounts
namespaces
environment
capabilities
resource configuration
```

`runc` is an OCI-compatible runtime.

---

# 8. Linux Namespaces

Namespaces answer:

> What can this process see?

They create isolated views of system resources.

Common namespaces include:

```text
PID namespace
→ isolated process ID view

Network namespace
→ isolated network interfaces, routes and addresses

Mount namespace
→ isolated filesystem mount view

UTS namespace
→ isolated hostname/domain name

IPC namespace
→ isolated inter-process communication

User namespace
→ isolated user/group ID mapping
```

Example with PID namespace:

```text
Host:
nginx PID = 5321

Inside container:
nginx PID = 1
```

It is still the same process, but the kernel presents a different PID view.

A namespace does not create another kernel.

The same Linux kernel gives different processes different views.

---

# 9. Linux Cgroups

Cgroups answer:

> How many resources can this process use?

They can control/account for resources such as:

- CPU
- Memory
- Process count
- I/O

Conceptually:

```text
Container process
      ↓
Cgroup
├── CPU rules
├── memory rules
└── process limits
```

The Linux kernel enforces those limits.

Docker does not continuously sit there checking the application manually.

Example idea:

```text
Process asks for memory
        ↓
Kernel
        ↓
Check process cgroup
        ↓
Allowed?
```

---

# 10. Namespaces vs Cgroups

This is one of the most important Docker concepts.

```text
Namespaces
= isolation
= what the process can see

Cgroups
= resource control
= how much the process can use
```

Together:

```text
                Container process
                       |
              ┌────────┴────────┐
              |                 |
         Namespaces          Cgroups
              |                 |
      isolated views       resource control
```

---

# 11. PID 1 in Containers

Every container has a first process in its PID namespace.

That process becomes:

```text
PID 1
```

Example:

```text
container
└── PID 1 → nginx
```

PID 1 is important because it has special process-management responsibilities.

It should correctly handle:

- Signals
- Child processes
- Exit behavior

This is why keeping a container alive with fake commands is a bad practice.

Examples of bad keep-alive tricks:

```bash
tail -f /dev/null
sleep infinity
while true; do ...; done
```

A container should stay alive because its real service is running in the foreground.

Example:

```bash
nginx -g 'daemon off;'
```

or:

```bash
php-fpm -F
```

---

# 12. ENTRYPOINT vs CMD

Both define what runs when the container starts, but they have different roles.

Example:

```dockerfile
ENTRYPOINT ["python3"]
CMD ["app.py"]
```

This becomes:

```text
python3 app.py
```

A useful mental model:

```text
ENTRYPOINT
→ fixed executable

CMD
→ default arguments/default command
```

For many simple service containers, using only `CMD` is enough.

---

# 13. `exec` in Startup Scripts

Suppose a startup script contains:

```sh
#!/bin/sh

prepare_something

exec nginx -g 'daemon off;'
```

`exec` replaces the shell process with NGINX.

Without `exec`:

```text
PID 1 → shell
          ↓
        nginx
```

With `exec`:

```text
PID 1 → nginx
```

This is usually better for signal handling and container lifecycle.

---

# 14. Docker Networks

Containers often need to communicate with each other.

For Inception:

```text
Browser
   ↓
NGINX :443
   ↓
WordPress/PHP-FPM :9000
   ↓
MariaDB :3306
```

A user-defined Docker bridge network works like a private virtual network for containers on the same host.

Example:

```bash
docker network create inception
```

Then:

```bash
docker run --network inception --name mariadb ...
docker run --network inception --name wordpress ...
```

Containers on the same user-defined network can communicate using container/service names.

---

# 15. Docker DNS

Docker provides internal DNS on user-defined networks.

If WordPress connects to:

```text
mariadb:3306
```

Docker can resolve:

```text
mariadb
   ↓
MariaDB container IP
```

So we do not need to hardcode container IP addresses.

This is useful because container IPs can change.

---

# 16. Network Interfaces, veth and Bridge

Each container can have its own network namespace.

Inside a container, we may see:

```text
eth0
```

Docker commonly connects container network namespaces to a Linux bridge using a **veth pair**.

Think of a veth pair as a virtual cable:

```text
Container
  eth0
   |
   | veth pair
   |
Host side veth
   |
Linux bridge
```

With two containers:

```text
Container A
   eth0
     |
    veth
     |
     +------ Linux bridge ------+
                                |
                               veth
                                |
                              eth0
                          Container B
```

---

# 17. Routing Table

The routing table answers:

> Which network path/interface should be used for this destination?

Inside a container we may have something like:

```text
172.20.0.0/16 → eth0
default        → Docker gateway
```

DNS answers:

```text
What IP address belongs to this name?
```

Routing answers:

```text
Which way should I send packets to reach that IP?
```

Port answers:

```text
Which service/process should receive the traffic?
```

---

# 18. Ports

A port identifies a network service on a machine/interface.

Examples:

```text
443  → HTTPS
9000 → PHP-FPM FastCGI
3306 → MariaDB/MySQL protocol
```

Docker publishing:

```bash
docker run -p 443:443 nginx
```

means conceptually:

```text
Host port 443
      ↓
Container port 443
```

---

# 19. `ports` vs `expose`

Example:

```yaml
ports:
  - "443:443"
```

This publishes a container port to the host.

Example:

```yaml
expose:
  - "3306"
```

This documents/internalizes the service port for container-to-container use.

On a user-defined Docker network, containers can communicate with each other's listening ports even without `expose`.

The application itself must actually listen on that port.

---

# 20. `0.0.0.0` vs `127.0.0.1`

Inside a container:

```text
127.0.0.1
→ only this container's loopback interface
```

```text
0.0.0.0
→ listen on all IPv4 interfaces available in the container
```

For MariaDB to accept connections from WordPress in another container, it may need to listen on a non-loopback interface.

Example:

```ini
bind-address=0.0.0.0
```

---

# 21. TCP Basics

Docker networking still uses normal networking protocols.

For TCP, connection establishment uses the 3-way handshake:

```text
Client                    Server

SYN
------------------------->

            SYN + ACK
<-------------------------

ACK
------------------------->
```

After that, application data can be exchanged.

Each direction has its own TCP sequence-number space.

---

# 22. Docker Volumes

Containers are disposable.

If important data exists only in the container writable layer, deleting the container can delete that data.

A Docker volume stores persistent data independently of the container lifecycle.

Example:

```text
MariaDB container
      ↓
/var/lib/mysql
      ↓
Docker volume
```

The container can be recreated while the database data remains.

---

# 23. Docker Volume vs Bind Mount

## Named volume

Example:

```yaml
volumes:
  - mariadb_data:/var/lib/mysql
```

Docker manages the volume object.

## Bind mount

Example:

```bash
-v /home/wel-mjiy/data:/var/lib/mysql
```

A specific host directory is directly mounted into the container.

Simple comparison:

```text
Named volume
→ Docker-managed storage object

Bind mount
→ user-selected host path
```

---

# 24. Docker Compose

Docker Compose does not create a different type of Docker image.

The image is the same.

Without Compose:

```bash
docker network create inception
docker volume create mariadb
docker run ...
docker run ...
docker run ...
```

With Compose:

```bash
docker compose up
```

because the configuration is written in:

```text
docker-compose.yml
```

Compose is basically:

> A tool that reads a YAML description of a multi-container application and asks Docker to create the required containers, networks, volumes, mounts, ports and configuration.

---

# 25. How Docker Compose Works

Example:

```yaml
services:
  mariadb:
    build: ./requirements/mariadb
    networks:
      - inception
    volumes:
      - mariadb:/var/lib/mysql

  wordpress:
    build: ./requirements/wordpress
    networks:
      - inception
    depends_on:
      - mariadb

  nginx:
    build: ./requirements/nginx
    networks:
      - inception
    depends_on:
      - wordpress
    ports:
      - "443:443"

networks:
  inception:

volumes:
  mariadb:
```

When we run:

```bash
docker compose up -d --build
```

Compose roughly:

```text
reads docker-compose.yml
        ↓
builds required images
        ↓
creates networks
        ↓
creates volumes
        ↓
creates containers
        ↓
mounts volumes
        ↓
connects networks
        ↓
starts containers
```

`-d` means detached/background mode.

`--build` means rebuild images when needed.

---

# 26. `depends_on`

Example:

```yaml
wordpress:
  depends_on:
    - mariadb
```

It controls container startup ordering.

It does not automatically guarantee that MariaDB is fully ready to accept connections.

Important distinction:

```text
container started
≠
application ready
```

For strong readiness handling, health checks or application-level waiting logic can be used.

---

# 27. Docker Secrets

Sensitive information should not be hardcoded into Dockerfiles.

Examples of sensitive values:

- Database passwords
- Root passwords
- WordPress passwords
- API keys

Docker Compose can make secrets available to selected containers as files.

Example:

```yaml
services:
  mariadb:
    secrets:
      - db_password

secrets:
  db_password:
    file: ../secrets/db_password.txt
```

Inside the container:

```text
/run/secrets/db_password
```

A script can read it:

```sh
DB_PASSWORD=$(cat /run/secrets/db_password)
```

Important:

> Docker secrets do not magically protect a badly stored source secret file.

The source files still need correct host permissions and should not be committed to Git.

---

# 28. Environment Variables vs Secrets

Use environment variables for normal configuration.

Examples:

```env
DOMAIN_NAME=wel-mjiy.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
```

Use secrets for sensitive values.

Examples:

```text
database password
root password
WordPress admin password
```

Mental model:

```text
.env
→ normal configuration

secrets/
→ confidential values
```

---

# 29. `.gitignore` for Secrets

Example:

```gitignore
secrets/
srcs/.env
```

To check whether a `.env` file was committed before:

```bash
git log --all -- srcs/.env
```

To check whether Git tracks environment files now:

```bash
git ls-files | grep '\.env'
```

To search all Git objects/history for `.env` paths:

```bash
git rev-list --objects --all | grep '\.env'
```

If a secret file was already committed, adding it to `.gitignore` does not remove it from old Git history.

---

# 30. Dockerfile Important Instructions

## FROM

Choose the base image:

```dockerfile
FROM debian:bookworm
```

## RUN

Execute commands while building:

```dockerfile
RUN apt update && apt install -y nginx
```

## COPY

Copy files from build context into the image:

```dockerfile
COPY nginx.conf /etc/nginx/nginx.conf
```

## WORKDIR

Set the working directory:

```dockerfile
WORKDIR /var/www/wordpress
```

## ENV

Define environment variables:

```dockerfile
ENV MODE=production
```

## CMD

Define default command/arguments for container startup:

```dockerfile
CMD ["nginx", "-g", "daemon off;"]
```

## ENTRYPOINT

Define the main executable:

```dockerfile
ENTRYPOINT ["/entrypoint.sh"]
```

---

# 31. Build-time vs Runtime

This distinction is extremely important.

```text
Dockerfile RUN
→ build time

CMD / ENTRYPOINT
→ runtime
```

Example:

```dockerfile
RUN apt install -y nginx
```

runs while creating the image.

But:

```dockerfile
CMD ["nginx", "-g", "daemon off;"]
```

runs when a container is created and started from that image.

---

# 32. Docker Image vs Container

Image:

```text
read-only
template
not running
reusable
```

Container:

```text
running instance of image
has writable layer
has processes
has network namespace
can have mounted volumes
```

Remember:

> Image is the blueprint. Container is the running environment created from the blueprint.

---

# 33. `docker run`, `docker start`, `docker exec`

## docker run

Creates a new container and starts it:

```bash
docker run nginx
```

## docker start

Starts an existing stopped container:

```bash
docker start nginx
```

## docker exec

Starts an additional process inside an already-running container:

```bash
docker exec -it nginx sh
```

It does not create a new container.

---

# 34. Useful Docker Commands

## Containers

```bash
docker ps
docker ps -a
docker stop <container>
docker start <container>
docker restart <container>
docker rm <container>
docker rm -f <container>
docker logs <container>
docker exec -it <container> sh
```

## Images

```bash
docker images
docker build -t myimage .
docker rmi <image>
docker pull <image>
```

## Networks

```bash
docker network ls
docker network inspect <network>
docker network create <network>
docker network rm <network>
```

## Volumes

```bash
docker volume ls
docker volume inspect <volume>
docker volume create <volume>
docker volume rm <volume>
```

## Compose

```bash
docker compose up
docker compose up -d
docker compose up -d --build
docker compose down
docker compose down -v
docker compose ps
docker compose logs
```

---

# 35. Docker Without `sudo`

Docker commands often require root privileges.

A user can be added to the Docker group:

```bash
sudo usermod -aG docker $USER
```

Then log out and log back in.

Security note:

> Membership in the Docker group effectively gives very powerful access to the machine and should be treated carefully.

---

# 36. NGINX in Inception

NGINX is the only public entry point in the Inception infrastructure.

Conceptually:

```text
Browser
   ↓
HTTPS :443
   ↓
NGINX
```

NGINX can:

- Serve static files
- Terminate TLS
- Forward PHP requests to PHP-FPM
- Act as a reverse proxy

For WordPress PHP requests:

```text
Browser
   ↓
NGINX
   ↓
FastCGI
   ↓
PHP-FPM
```

NGINX does not execute PHP itself.

---

# 37. HTTPS and TLS

HTTPS means:

```text
HTTP over TLS
```

TLS provides:

- Encryption
- Integrity
- Server authentication

NGINX needs:

```text
certificate
private key
```

A self-signed certificate can encrypt traffic, but browsers do not automatically trust it because it is not signed by a trusted certificate authority.

---

# 38. WordPress and PHP-FPM

WordPress is a PHP web application.

PHP-FPM means:

> PHP FastCGI Process Manager

It manages PHP worker processes.

Architecture:

```text
NGINX
   ↓ FastCGI
PHP-FPM
   ↓
executes WordPress PHP
```

A PHP-FPM pool is a group of worker processes sharing configuration.

Example ideas:

```text
pm.max_children
→ maximum workers

pm.start_servers
→ workers created initially

pm.min_spare_servers
→ minimum idle workers

pm.max_spare_servers
→ maximum idle workers
```

---

# 39. MariaDB

MariaDB is a relational database management system.

WordPress stores its data in MariaDB tables.

Examples:

```text
wp_users
wp_posts
wp_options
wp_comments
wp_usermeta
```

Important distinction:

```text
Linux mysql user
≠
MariaDB database user
≠
WordPress website user
```

These are three different concepts.

---

# 40. WordPress → MariaDB Communication

WordPress code generates SQL queries.

The PHP MySQL/MariaDB extension sends them to the database server.

Conceptually:

```text
WordPress PHP code
      ↓
php-mysql extension
      ↓
TCP connection
      ↓
mariadb:3306
      ↓
MariaDB server
```

The PHP extension does not decide what SQL to execute.

The WordPress application code does.

---

# 41. WP-CLI

WP-CLI is a command-line tool for managing WordPress.

Example:

```bash
wp core download
wp core install
wp user create
```

Important:

```text
WP-CLI
≠
WordPress website
```

WP-CLI is the management tool.

WordPress is the actual PHP application.

If WordPress is installed in:

```text
/var/www/wordpress
```

WP-CLI needs to run from that directory or use:

```bash
--path=/var/www/wordpress
```

---

# 42. Inception Architecture

A simplified architecture:

```text
                    Ubuntu VM
                       |
                     Docker
                       |
                Docker network
        ┌──────────────┼──────────────┐
        |              |              |
      NGINX         WordPress       MariaDB
       :443           :9000          :3306
        |              |              |
        |              |              |
        |              └──────────────┘
        |
     Browser
```

The communication flow:

```text
Browser
  ↓ HTTPS/TLS
NGINX :443
  ↓ FastCGI
WordPress / PHP-FPM :9000
  ↓ MariaDB protocol
MariaDB :3306
```

---

# 43. Virtual Machine vs Container

A VM contains its own guest operating system and kernel.

```text
Hardware
   ↓
Hypervisor
   ↓
VM
├── guest kernel
└── applications
```

Containers share the host Linux kernel.

```text
Host Linux kernel
      |
   Docker
   /    \
Container Container
```

Containers are generally lighter because each one does not need a complete guest kernel.

---

# 44. Why Docker Became Popular

Containerization existed before Docker.

Examples include:

- `chroot`
- FreeBSD Jails
- Solaris Zones
- OpenVZ
- LXC

Docker did not invent the basic idea of containers.

Docker made container workflows much easier with:

- Dockerfiles
- Images
- Registries
- Simple CLI
- Networks
- Volumes
- Docker Compose

---

# 45. Docker Registry and Docker Hub

A registry stores Docker images.

Docker Hub is a popular public registry.

Example:

```bash
docker pull nginx
```

downloads an image from a registry.

Example:

```bash
docker push username/myimage
```

uploads an image to a registry, assuming authentication and permissions are configured.

A registry stores images, not running containers.

---

# 46. Why Containers Are Isolated

A container is not isolated because Docker invented a separate kernel.

It is isolated because Docker/runc configure Linux kernel features around the process.

Simplified:

```text
Application process
        |
        ├── PID namespace
        ├── network namespace
        ├── mount namespace
        ├── UTS namespace
        ├── IPC namespace
        ├── cgroups
        ├── capabilities
        └── root filesystem
```

This creates the container environment.

---

# 47. Complete Mental Model

When we build:

```text
docker build
    ↓
Docker CLI
    ↓
dockerd
    ↓
BuildKit
    ↓
Dockerfile
    ↓
image layers
    ↓
Image
```

When we run:

```text
docker run image
    ↓
Docker CLI
    ↓
dockerd
    ↓
containerd
    ↓
containerd-shim
    ↓
runc
    ↓
Linux kernel
    ↓
namespaces + cgroups + mounts
    ↓
application process
```

When we use Compose:

```text
docker-compose.yml
        ↓
Docker Compose
        ↓
Docker Engine
        ↓
images
containers
networks
volumes
secrets
ports
```

---

# 48. Important Rules to Remember

```text
Dockerfile
= recipe for an image

Image
= read-only template

Container
= isolated running process/environment

BuildKit
= builds images

dockerd
= high-level Docker daemon

containerd
= container lifecycle/runtime manager

shim
= stays near the running container process

runc
= creates the low-level Linux container

Namespaces
= what the process can see

Cgroups
= how many resources it can use

OverlayFS
= combines image layers + writable container layer

Volume
= persistent storage

Docker network
= communication between containers

Docker Compose
= describes and manages a multi-container application
```

---

# 49. Recommended Learning Order

For someone learning Docker from zero, this order works well:

1. Process basics in Linux
2. Image vs container
3. Dockerfile
4. `docker build`
5. `docker run`
6. Ports
7. Volumes
8. Networks
9. Docker Compose
10. Environment variables
11. Secrets
12. PID 1
13. Namespaces
14. Cgroups
15. OverlayFS
16. BuildKit
17. containerd / shim / runc
18. OCI
19. Build a real multi-container project

Do not try to memorize everything at once.

The best way to learn Docker is:

```text
learn concept
   ↓
run command
   ↓
inspect result
   ↓
break something
   ↓
debug it
   ↓
understand why
```

---

# 50. Final Summary

Docker is mainly a convenient platform built on top of Linux container technologies.

At a high level:

```text
Dockerfile
   ↓
BuildKit
   ↓
Image
   ↓
Docker runtime stack
   ↓
Container
   ↓
Linux process
```

At a lower level:

```text
Container
=
normal Linux process
+
namespaces
+
cgroups
+
mounts
+
capabilities
+
container filesystem
```

And for a multi-container project:

```text
Docker Compose
=
one configuration file
that describes how all containers,
networks, volumes, ports, environment variables,
and secrets should work together.
```

The most important lesson is not learning Docker commands by heart.

It is understanding:

> **What process is running, what filesystem it sees, what network it uses, where its data is stored, and which Linux kernel features are isolating and controlling it.**

---

# Author

**Name / 42 login:** `wel-mjiy`

This documentation was written from the concepts learned while preparing and building the 42 Inception project.
