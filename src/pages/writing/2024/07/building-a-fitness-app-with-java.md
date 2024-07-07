---
layout: '@layouts/BlogLayout.astro'
title: 'Part one - Building a fitness tracking app with Java'
pubDate: 2024-07-07
description: 'How I built a fitness tracking app using Java, MySQL and React Native'
draft: true
---

## The problem

I am very interested in fitness, I go to the gym 4/5 times a week and really enjoy the tracking and progression aspects of it. To keep track of things, I use:
- **A spreadsheet**, here I log my lifts for each session, my maximum lifts, caloric intake and various other food-based calculations. 
- **MyFitnessPal**, for logging food eaten and my weight
- **Garmin Connect**, for logging health stats like daily sleep and resting heart rate.

Whilst this works OK, I rarely log my actual lifts at the gym itself, and end up doing it when I go home. Sometimes I end up forgetting to do this, and other times I misremember specific lifts I've done. I also miss out on one of my favourite things at the gym, logging the activity itself - it feels really good when you've hit a new weight/rep maximum and logging it.

## The idea

My idea is to create a fitness tracking app where I can log my lifts and weight, whilst using my other data sources (MyFitnessPal and Garmin Connect) to enrich this data. I can then see things like how my caloric intake and sleep affect my performance and various other (most likely useless) information.

In the past I have built something quite similar to this, but the project fizzled out when I got to the part where I had to build the UI for logging activities and actually hosting it on a server so I could use it in public.

For this project I have a few aims:
- Use the latest version of technologies I use at work (Java, Spring), and introduce some new ones.
- Gain more experience building React Native applications
- Build something that's actually useful for me and my day-to-day life

I'm fully aware that app exist that do these things (probably), but the goals are more focused on learning new things and having an interesting side project to work on, rather than building an app to make money, or solve problems for a large group of people. Similarly for different aspects of the app, I'm going to build almost everything from scratch (e.g. auth) rather than something off the shelf - I may change this approach if I start spending too long on those things.

## Building it

For part one, I'm going to focus on setting up the project and designing things, rather than going straight in and writing lots of code.

I have a general idea of how I'm going to approach this:
- Setting up the project, this includes things like the database migration process, running the tests and building/running the app locally.
- Plan the basic functionality the app will have in text form
- Design the database schema (I already have an old schema to work with, which needs a few modifications)
- Design a basic app flow, based on how I'd like to use it

### Setting up the project

Firstly we'll need the the Java 22 SDK for writing code, I got this by using `sdkman` and running this:

```bash
sdk install java 22.0.1-tem
```
...and made sure it was installed:

```
$ java -version
openjdk version "22.0.1" 2024-04-16
OpenJDK Runtime Environment Temurin-22.0.1+8 (build 22.0.1+8)
OpenJDK 64-Bit Server VM Temurin-22.0.1+8 (build 22.0.1+8, mixed mode, sharing)
```

Next we'll create our Spring project, using [Spring Initializr](https://start.spring.io), we'll add the following additional deps:
- Spring Web
- Spring Boot DevTools
- JOOQ (something I'd like to try for DB access)
- MySQL DB Driver

I might be missing some, but we can always add them later on. You can use [this link](https://start.spring.io/#!type=maven-project&language=java&platformVersion=3.3.1&packaging=jar&jvmVersion=22&groupId=com.dmoffat&artifactId=fitnesstracker&name=fitnesstracker&description=Fitness%20tracking%20application&packageName=com.dmoffat.fitnesstracker&dependencies=web,jooq,devtools,mysql) to see the exact configuration I chose.

I unzipped the downloaded ZIP file and filled in my `.gitignore`.

Now we have a fully functional Spring app (that doesn't even start, for the moment).

### Setting up the database

Before we can run our app, we need to set up a database. As mentioned in my previous blog posts, I use Docker to manage running different services on my local machine. Let's use Docker to create a MySQL instance. Because I'm planning on running multiple services on my computer (MySQL, Java app and a web server (reverse proxy)), I'll use Docker Compose to manage my Docker containers.

To use Docker Compose we'll need to create a `docker-compose.yml` config file. I used [the official reference](https://docs.docker.com/compose/compose-file/) to figure out how to write the config file (we use it at work for local dev, so I do have a general idea on the different elements).

It looks something like this:

```yaml
name: fitnesstracker
services:
  db: 
    image: mysql:8.0.38
    container_name: 'ft-mysql'
    ports:
      # Use a port different to the default so we don't have to stop any running MySQL databases
      - 3310:3306
    restart: always
    volumes:
      # Use a persistent data directory
      - ./db/data:/var/lib/mysql
    environment:
      # This is temporary so we can make sure things working, this won't be used for production.
      MYSQL_ROOT_PASSWORD: example
```

I read through the [offical MySQL docker image docs](https://hub.docker.com/_/mysql) to configure it. I decided to use `8.0.38` as that version is supported by the DB access library I want to use (JOOQ).

Next I started the app services (in this case, just the DB) to make sure it works:

```
$ docker compose up -d
[+] Running 2/2
 ✔ Network fitnesstracker_default  Created                                                                                                                                                                                             0.1s 
 ✔ Container ft-mysql              Started 
```

I then made sure I could connect to the database using the `mysql` CLI:

```
$ mysql -h 172.21.0.2 -u root -p
Enter password: 
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 11
Server version: 8.0.38 MySQL Community Server - GPL

Copyright (c) 2000, 2024, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> select User from mysql.user;
+------------------+
| User             |
+------------------+
| root             |
| mysql.infoschema |
| mysql.session    |
| mysql.sys        |
| root             |
+------------------+
5 rows in set (0.00 sec)

mysql> 
```

Now that the database is running, we'll need to update our Java app to connect to it.

> **Side note**: For now, I'm using the root DB user in my app, and I've put the database password in plain text in the repo. I've done this to make sure DB connectivity works. In the future, I'll create a different user, and remove sensitive credentials from the repo. I KNOW THIS IS WRONG/BAD PRACTICE.

I added the following to `application.properties`:

```conf
spring.datasource.url=jdbc:mysql://<db_host>
spring.datasource.username=<db_user>
spring.datasource.password=<db_password>
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver
spring.jpa.show-sql=true
```

I then started my app (through the IDE) and made sure it connected to the database.

### Setting up database migrations

At work we use a homegrown migration system which runs Groovy scripts. For this project I'm going to use Flyway, a Java-based database migration tool that handles migrations with plain SQL. I wanted to use something that's a bit more standardised and could be used on multiple projects.

After installing it, I wrote my first migration:

todo: Install it