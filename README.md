Containerizing Analytics Pipelines with Docker
==============================================

Jeff Walker

Big Data Deep Analytics Portland Maine

2015-07-09

Useful links on data containers and loose coupling:

- <https://medium.com/@ramangupta/why-docker-data-containers-are-good-589b3c6c749e>
- <http://stackoverflow.com/questions/18496940/how-to-deal-with-persistent-storage-e-g-databases-in-docker/20652410#20652410>
- <http://www.offermann.us/2013/12/tiny-docker-pieces-loosely-joined.html>
- <http://crosbymichael.com/advanced-docker-volumes.html>
- <http://container42.com/2013/12/16/persistent-volumes-with-docker-container-as-volume-pattern/>
- <http://container42.com/2014/11/18/data-only-container-madness/>

# Today's Goal

> Create a containerized analytics pipeline that separates data sources and analytics platforms

# Why?

1. Reproducibility
1. Collaboration

# Plan

Data Containers:

- Txt Files
- [ PostgreSQL ] - didn't get there, but see [this](https://registry.hub.docker.com/_/postgres/)

Analytics Containers:

- R/[RStudio Server](https://www.rstudio.com/products/rstudio/download-server/)
- Python/[IPython Notebook](http://ipython.org/notebook.html)

# Docker

Three Components:

1. **Images**: snapshot of a filesystem
1. **Containers**: running instance of an image
1. **Volumes**: mounted directory

# Boot2Docker

Lightweight linux virtual machine required for Mac/Windows

[Homepage](http://boot2docker.io/)

**Boot2Docker IP Address**: Need to use this when connecting to docker containers through the browser (replaces `localhost`)

```sh
boot2docker ip
```

Boot2Docker has a number of commands that control the virtual machine.

**Note**: it seems that boot2docker will stop working properly if you switch wifi. In the meetup, we couldn't connect to the internet from within docker. When I got home, I had similar problems. Deleting the virtual machine and restarting seemed to work, though I did lose all the images I had saved, so this is not a good solution.

```sh
boot2docker delete
boot2docker init
boot2docker start
```

# Docker

Hello World

```sh
docker run hello-world
```

Docker Hub: <https://registry.hub.docker.com/>

Ubuntu bash

```sh
docker run -it ubuntu bash
```

Note that after exiting the container shell, the container is stopped but still exists.

List the running containers:

```sh
docker ps -a
```

Remove the ubuntu container:

```sh
docker rm <container id>
```

When creating a container that you only want to use once, use the `--rm` flag to automatically delete it after your done.

```sh
docker run -it --rm ubuntu bash
docker ps -a
# no ubuntu container should be listed
```

## Create a data container

Use `busybox` image to create a data container. Assign name `flow-data`.

```sh
docker run --name flow-data -v /data busybox /bin/sh
```

Open new shell attached to data container, install wget and download data.

```sh
docker run -it --volumes-from flow-data ubuntu bin/bash
cd /data
sudo apt-get update
sudo apt-get install -y wget
wget https://s3.amazonaws.com/walkerjeffd_bucket/androscoggin.txt
exit
```

To open a shell on an existing container use `exec`. First, check container list, then start the last ubuntu container and then open interactive shell.

```sh
docker ps -a
docker start <commit id>
docker exec -it <commit id> bin/bash
cd /data
ls
```

# R/RStudio Server Container

- <https://registry.hub.docker.com/repos/rocker/>
- <https://github.com/rocker-org/rocker>
- <https://github.com/rocker-org/rocker/wiki/Using-the-RStudio-image>

Run the `rocker/hadleyverse` image as a background process (`-d`) and mapping port `8787`.

```sh
docker run -d -p 8787:8787 rocker/hadleyverse
```

Open `http://<ip address>:8787` and log in with user `rstudio`, password `rstudio`. Remember to use the boot2docker IP if on windows or mac, otherwise use localhost on linux.

Stop and delete the rstudio container so we can create a new one that will have access to the data volume.

```sh
docker ps -a
docker stop <container id>
docker rm <container id>
```

Now create a new hadleyverse container with attached data volume using `--volumes-from`, and a mounted host volume that maps `./code` on the host to `/code` in the container using `-v`. The `$(pwd)` is a shell command to fill in the absolute path to the local `./code` directory (docker requires absolute paths).

```sh
docker run -d -p 8787:8787 --volumes-from flow-data -v $(pwd)/code:/code rocker/hadleyverse
```

Open `http://<ip address>:8787` and log in again. Change the working directory to `/code` and open `load_data.R`. Start running the code, line by line. You should find that the `lubridate` package is not available. So just install it in the R console:

```r
install.packages('lubridate')
```

Now if you shutdown and remove this container, then create a new hadleyverse container you will have to install the package again.

After installing `lubridate`, then save a snapshot of the container as a new image. The images list should now contain our new image `my_rstudio`.

```sh
docker commit <container id> my_rstudio
docker images
```

Now we can shutdown and remove the container and start a new one from the image we just created.

```sh
docker run -d -p 8787:8787 --volumes-from flow-data -v $(pwd)/code:/code my_rstudio
```

Open RStudio in browser and open `/code/load_data.R` and we should find that the `lubridate` package is now available.

# RStudio Dockerfile

Instead of manually installing the package in an active container, we can create a Dockerfile that will generate the same image by stepping through a list of commands.

The `./Dockerfile` in this repo extends the `rocker/hadleyverse` image by installing `lubridate`.

To create this image, run the `build` command. The images list should now contain our new `my_rstudio2` image.

```sh
docker build -t my_rstudio2 .
docker images
```

Start new container from this image (note you'll have to make sure any previous RStudio containers are stopped, or else you'll get an error about the port being in use):

```sh
docker run -d -p 8787:8787 --volumes-from flow-data -v $(pwd)/code:/code my_rstudio2
```

And we should see that the new container based on `my_rstudio2` has lubridate installed.

# IPython Notebook

Dockerfile Repo: <https://github.com/ipython/docker-notebook>

Note that we're running this one as an interactive container (`-it`) rather than a background process (`-d`) as we did with rstudio. This is so that we can see the log output from the IPython server. Once this process is stopped, the server is no longer available.

```sh
docker run -it -e PASSWORD=bigdata -p 8888:8888 -e "USE_HTTP=1" --rm --volumes-from flow-data -v $(pwd)/notebooks:/notebooks ipython/scipyserver
```

Open browser to `http://<ip address>:8888` and log in with the password specified by `PASSWORD`. No additional packages are necessary so this should work straight out of the box.