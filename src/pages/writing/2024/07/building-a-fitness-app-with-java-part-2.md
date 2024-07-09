---
layout: '@layouts/BlogLayout.astro'
title: 'Part two - Building a fitness tracking app with Java'
pubDate: 2024-07-09
description: 'How I built a fitness tracking app using Java, MySQL, React Native and more.'
draft: true
---

- [What we're going to work on](#what-were-going-to-work-on)
- [Integrating jOOQ](#integrating-jooq)
  - [What is jOOQ?](#what-is-jooq)
  - [Why not use Hibernate?](#why-not-use-hibernate)
  - [Setting up](#setting-up)
  - [Using the generated classes](#using-the-generated-classes)
  - [Creating DAOs](#creating-daos)
- [Securing our API](#securing-our-api)
  - [Installing Spring Session](#installing-spring-session)
  - [Configuring Spring Session](#configuring-spring-session)
  - [Installing Spring Security](#installing-spring-security)
  - [Configuring Spring Security](#configuring-spring-security)
- [Building the structure of our backend APIs and writing models](#building-the-structure-of-our-backend-apis-and-writing-models)


## What we're going to work on

In this post we're going to look at building the following:
- Integrating jOOQ for data access
- Securing our API by building an authentication mechanism
- Building the structure of the backend APIs + writing the models

## Integrating jOOQ

### What is jOOQ?

If you're unfamilar with jOOQ, it's a library that generates Java classes from your database structure, letting you write type safe queries.

### Why not use Hibernate?

In my day-to-day work, and in other projects, I've used either Hibernate, or plain JDBC. 

For Hibernate specifically, I really dislike the following:
- Doing anything more than a simple join seems overly complicated, for example when you start fetching associations which have their own associations.
- Half the time you are trying to conjure the right combination of annotations to get Hibernate to produce the SQL you want, you end up just writing HQL anyway.
- Once you learn these things, you can't apply the knowledge anywhere else - which I guess is true for lots of things, but I really do feel cheated when I spend an hour making Hibernate behave the way I want to.

These problems could be down to my own ignorance or ineptitutde, but I don't think it should be this complicated. I know the exact SQL I want to write, I just need something to map the result set into POJOs.

### Setting up

We've already got the `jooq` dependency in our `pom.xml`:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-jooq</artifactId>
</dependency>
```

Next we need to set up the Maven code generator, which comes in the form of a Maven plugin:

```xml
<plugin>
    <groupId>org.jooq</groupId>
    <artifactId>jooq-codegen-maven</artifactId>
    <version>3.19.10</version>
    <configuration>
        <!-- Connection config -->
        <jdbc>
            <driver>com.mysql.cj.jdbc.Driver</driver>
            <url>jdbc:mysql://${DB_HOST}/</url>
            <user>${DB_USER}</user>
            <password>${DB_PASSWORD}</password>
        </jdbc>
        <!-- Generator config -->
        <generator>
            <database>
                <name>org.jooq.meta.mysql.MySQLDatabase</name>
                <!-- Which tables to include -->
                <includes>.*</includes>
                <excludes></excludes>
                <!-- The schema -->
                <inputSchema>ft</inputSchema>
            </database>
            <!-- Where to put the generated code -->
            <target>
                <packageName>com.dmoffat.fitnesstracker.db</packageName>
                <directory>src/main/java</directory>
            </target>
        </generator>
    </configuration>

    <!-- Execute the plugin when we run `mvn generate-sources` -->
    <executions>
        <execution>
        <id>jooq-codegen</id>
        <phase>generate-sources</phase>
        <goals>
            <goal>generate</goal>
        </goals>
        </execution>
    </executions>
</plugin>
```

I read the following docs to figure this out:
- [Running the code generator with Maven](https://www.jooq.org/doc/latest/manual/code-generation/codegen-maven/)
- [Configuration and setup of the generator](https://www.jooq.org/doc/latest/manual/code-generation/codegen-configuration/)
- [Codegen Includes and Excludes](https://www.jooq.org/doc/latest/manual/code-generation/codegen-advanced/codegen-config-database/codegen-database-includes-excludes/)

And to generate the classes we run:

```bash
./mvnw generate-sources
```

This fails because Maven can't resolve `${DB_USER}`/`${DB_PASSWORD}`. Let's write a script (`generate-db-classes`) which exports variables in our `.env` file, and runs the aforementioned Maven command:

```bash
#!/usr/bin/env bash

set -o allexport
source ../.env
set +o allexport

./mvnw generate-sources
```

Running this produces the following:

```
[INFO] ----------------------------------------------------------
[INFO] Generating catalogs      : Total: 1
[INFO] Version                  : Database version is supported by dialect MYSQL: 8.0.38
[INFO] ARRAYs fetched           : 0 (0 included, 0 excluded)
[INFO] Domains fetched          : 0 (0 included, 0 excluded)
[INFO] Tables fetched           : 6 (6 included, 0 excluded)
[INFO] Embeddables fetched      : 0 (0 included, 0 excluded)
[INFO] Enums fetched            : 0 (0 included, 0 excluded)
[INFO] Packages fetched         : 0 (0 included, 0 excluded)
[INFO] Routines fetched         : 0 (0 included, 0 excluded)
[INFO] Sequences fetched        : 0 (0 included, 0 excluded)
[INFO] No schema version is applied for catalog . Regenerating.
[INFO]                          
[INFO] Generating catalog       : DefaultCatalog.java
[INFO] ==========================================================
[INFO] Comments fetched         : 0 (0 included, 0 excluded)
[INFO] Generating schemata      : Total: 1
[INFO] No schema version is applied for schema ft. Regenerating.
[INFO] Generating schema        : Ft.java
[INFO] ----------------------------------------------------------
[INFO] UDTs fetched             : 0 (0 included, 0 excluded)
[INFO] Generating tables        
[INFO] Generating table         : BodyWeight.java [input=body_weight, pk=KEY_body_weight_PRIMARY]
[INFO] Indexes fetched          : 5 (5 included, 0 excluded)
[INFO] Generating table         : Exercise.java [input=exercise, pk=KEY_exercise_PRIMARY]
[INFO] Generating table         : FlywaySchemaHistory.java [input=flyway_schema_history, pk=KEY_flyway_schema_history_PRIMARY]
[INFO] Generating table         : User.java [input=user, pk=KEY_user_PRIMARY]
[INFO] Generating table         : Workout.java [input=workout, pk=KEY_workout_PRIMARY]
[INFO] Generating table         : WorkoutExercise.java [input=workout_exercise, pk=KEY_workout_exercise_PRIMARY]
[INFO] Tables generated         : Total: 412.834ms
[INFO] Generating table records 
[INFO] Generating record        : BodyWeightRecord.java
[INFO] Generating record        : ExerciseRecord.java
[INFO] Generating record        : FlywaySchemaHistoryRecord.java
[INFO] Generating record        : UserRecord.java
[INFO] Generating record        : WorkoutRecord.java
[INFO] Generating record        : WorkoutExerciseRecord.java
[INFO] Table records generated  : Total: 485.481ms, +72.646ms
[INFO] Generating table references
[INFO] Table refs generated     : Total: 489.557ms, +4.076ms
[INFO] Generating Keys          
[INFO] Keys generated           : Total: 498.308ms, +8.75ms
[INFO] Generating Indexes       
[INFO] Indexes generated        : Total: 506.206ms, +7.897ms
[INFO] Generation finished: ft  : Total: 506.43ms, +0.224ms
```

Our classes got added to `server/src/main/java/db` which is great!

There were two problems I noticed when inspecting the classes:
1. It includes the `FlywaySchemaHistory` table, which we don't need
2. The foreign keys we defined in the previous post have auto-generated names (e.g. `user_id_ibfk_1`), resulting in our generated code having names like `BODY_WEIGHT_IBFK_1`. 

Both are simple fixes:
- Update `<excludes>` in our `pom.xml` to `<excludes>ft.flyway_schema_history</excludes>`
- Update the migration

### Using the generated classes

Now we've got our generated classes, let's query the database. Because our database doesn't have any data in, we'll quickly add some records to our `exercise` reference table and run that migration.
 
With Hibernate, you interact with the database using a `Session`/`EntityManager`. In jOOQ you use `DSLContext`.

I wrote a simple class named `ExerciseService` and added the following code:

```java
@Service
public class ExerciseService {
    private DSLContext dsl;

    @Autowired
    public ExerciseService(DSLContext dsl) {
        this.dsl = dsl;
    }

    public void printExercises() {
        Result<ExerciseRecord> exercises = dsl.selectFrom(Tables.EXERCISE).fetch();
        System.out.println(exercises);
    }
}
```

To test it, I created a test class and called the method I just wrote:

```java
@SpringBootTest
class ExerciseServiceTest {

    @Autowired
    private ExerciseService exerciseService;

    @Test
    void testJooqIntegration() {
        exerciseService.printExercises();
    }
}
```

We can see the following logs which proves it works:

```
Executing query          : select `ft`.`exercise`.`id`, `ft`.`exercise`.`name`, `ft`.`exercise`.`brand`, `ft`.`exercise`.`type` from `ft`.`exercise`
Version                  : Database version is supported by dialect MYSQL: 8.0.38
Fetched result           : +----+-------------------+------+-----------+
                         : |  id|name               |brand |type       |
                         : +----+-------------------+------+-----------+
                         : |   1|Back squat         |{null}|FREE_WEIGHT|
                         : |   2|Barbell Bench press|{null}|FREE_WEIGHT|
                         : |   3|Deadlift           |{null}|FREE_WEIGHT|
                         : +----+-------------------+------+-----------+
Fetched row(s)           : 3
```

Because this is just an example, I've used jOOQ classes directly in my service - in the actual app I'll create my own POJOs and not let jOOQs types leak into the rest of my code.

### Creating DAOs

Most Spring apps I've worked are split into 3 layers:
- **Controller**, this is where you do presentational things (defining HTTP responses, request validation, etc)
- **Service**, this is where your business logic goes (e.g. in an ecommerce website you'd find things like `BasketService#addToBasket`)
- **Repository/DAO**, this is where you access the database

I'm not really sure if this pattern has a name, but it seems pretty prevalent in Spring apps. The idea is that each layer only knows about the layer below it, for example, the service talks to the repository to fetch things from the database, but doesn't know that it's been called from a REST API endpoint. Similarly the repository just cares about talking to the database, it has no knowledge or reference to the service that calls it.

> **Side note**: I've heard people mention a benefit of being to swap databases (e.g. MySQL -> Oracle) without having to change any code, but in practice, I've never seen a product migrate from one database to another.

Usually in a Hibernate project, you end up creating some `HibernateDao<KeyType, EntityType>` class, I'll do the same for jOOQ, merely to wrap the jOOQ types and use my own models throughout the rest of the codebase.

I briefly looked at jOOQs generated DAOs (and [read the article "To DAO, or not to DAO?](https://blog.jooq.org/to-dao-or-not-to-dao/) written by jOOQ's author) and didn't see the benefit. Although the generated DAOs have a bunch of useful methods I'll most likely end up writing myself anyway, I don't like the fact it creates a POJO - my app would have three types representing one thing, `ExerciseRecord` (jOOQ database class), `Exercise` (jOOQ POJO) and `Exercise` (my own type). It's just needlessly complicated for no reason and goes against my own principle - don't create things that don't provide a clear benefit.

My DAO looks like this:

```java
@Repository
public class ExerciseDao {
    @Autowired private DSLContext context;

    public List<Exercise> findAll() {
        return context
            .selectFrom(EXERCISE)
            .fetchInto(Exercise.class);
    }

    public Exercise findOne(Integer id) {
        return context
            .selectFrom(EXERCISE)
            .where(EXERCISE.ID.eq(UInteger.valueOf(id)))
            .fetchOneInto(Exercise.class);

    }
}
```

Maybe when I need to, I'll create a generic jOOQ DAO you can extend (or use their provided `DAOImpl`), for now, this will suffice.

## Securing our API

We need to secure our API so that only I can access it - we don't want other people logging workouts for my user account.

The basic premise for securing our app will be:
- Mobile app makes request to `/auth/login` API
- `/auth/login` API validates details with user database, creates a session and returns a session token
- Mobile app stores session token in secure storage and includes it in the `Authorization` header in subsequent requests.
- In subsequent requests, say for example, for logging a workout, the server will log the workout for the user that's contained in the session token.

The downside to this approach is that each call to the API will incur a session lookup. I think this is acceptable as the app will have at most 1 user (me!).

At work we use a home-grown authentication/session system, so for this project I'll use this opportunity to use Spring Security + Spring session. We'll need Spring Security to handle authn/authv and Spring Session for session management. By default sessions get stored in memory, but for this project, I'd like to store them in a database.


### Installing Spring Session

We add the following to our `pom.xml`

```xml
...
```

### Configuring Spring Session

To configure Spring session I read the documentation (provide a link to the spring session docs)

### Installing Spring Security

We add the following to our `pom.xml`:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>
```

### Configuring Spring Security

Spring Security has [some pretty extensive documentation](https://docs.spring.io/spring-security/reference/servlet/getting-started.html) which I read to configure it. I found the documentation extensive, but at times quite verbose.

... condense all of the stuff that we added to get this working ...

We can test this out by running the following:

```bash
curl -v --header "Content-Type: application/json" --request POST --data '{"email":"danmofo@gmail.com","password":"password"}' http://localhost:8080/
```

## Building the structure of our backend APIs and writing models