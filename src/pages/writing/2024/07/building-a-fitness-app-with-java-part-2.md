---
layout: '@layouts/BlogLayout.astro'
title: 'Building a fitness tracking app with Java - Part two'
pubDate: 2024-07-09
description: 'How I built a fitness tracking app using Java, MySQL, React Native and more.'
series_posts: 
  - name: Part one
    path: writing/2024/07/building-a-fitness-app-with-java-part-1
  - name: Part three 
    path: writing/2024/07/building-a-fitness-app-with-java-part-3
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
  - [Testing out Spring Session](#testing-out-spring-session)
  - [Installing Spring Security](#installing-spring-security)
  - [Configuring Spring Security](#configuring-spring-security)
  - [Testing out Spring Security](#testing-out-spring-security)
  - [Writing some integration tests](#writing-some-integration-tests)
- [Conclusion](#conclusion)

## What we're going to work on

As mentioned in [part one](/writing/2024/07/building-a-fitness-app-with-java-part-1), we're going to start building our backend API, we'll look at building the following:
- Integrating jOOQ for data access
- Securing our API by building an authentication mechanism

## Integrating jOOQ

### What is jOOQ?

If you're unfamilar with [jOOQ](https://www.jooq.org/), it's a library that generates Java classes from your database structure, letting you write type safe queries.

### Why not use Hibernate?

In my day-to-day work, and in other projects, I've used either Hibernate, or plain JDBC. 

For Hibernate specifically, I really dislike the following:
- Doing anything more than a simple join seems overly complicated, for example fetching associations which have their own associations.
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

This deals with setting up jOOQ for us automatically, and giving us access to a `DSLContext`, an object we can use for performing DB operations.

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

Which produces:

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

Everything seems to be working nicely.

### Creating DAOs

Most Spring apps I've worked are split into 3 layers:
- **Controller**, this is where you do presentational things (defining HTTP responses, request validation, etc)
- **Service**, this is where your business logic goes (e.g. in an ecommerce website you'd find things like `BasketService#addToBasket`)
- **Repository/DAO**, this is where you access the database

I'm not really sure if this pattern has a name, but it seems pretty prevalent in Spring apps. The idea is that each layer only knows about the layer below it, for example, the service talks to the repository to fetch things from the database, but doesn't know that it's been called from a REST API endpoint. Similarly the repository just cares about talking to the database, it has no knowledge or reference to the service that calls it.

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

You may notice it doesn't contain any methods to update an exercise, or create a new exercise - this is intentional. Because my app doesn't have this functionality (exercises will be managed through database migrations, and won't be editable by users), we don't need methods to do this.

## Securing our API

We need to secure our API so that only I can access it - we don't want other people logging workouts for my user account.

The basic premise for securing our app will be:
- Mobile app makes request to `/auth/login` API
- `/auth/login` API validates details with user database, creates a session and returns a session token
- Mobile app stores session token in secure storage and includes it in the `Authorization` header in subsequent requests.
- In subsequent requests, say for example, for logging a workout, the server will log the workout for the user that's contained in the session token.

The downside to this approach is that each call to the API will incur a session lookup. I think this is acceptable as the app will have at most 1 user (me!).

At work we use a home-grown authentication/session system, so for this project I'll use this opportunity to use Spring Security + Spring session. We'll need Spring Security to handle authn/authz and Spring Session for session management.


### Installing Spring Session

We add the following to our `pom.xml`

```xml
<dependency>
    <groupId>org.springframework.session</groupId>
    <artifactId>spring-session-jdbc</artifactId>
</dependency>
```

### Configuring Spring Session

By default, sessions (`HttpSession`) are stored in memory. This is fine for this project, but they have a large downside - when the app is restarted, all sessions will be lost, meaning I'll have to authenticate again. We need to persist the sessions in the database, so for this, I have to use `spring-session-jdbc`, which saves sessions in a database by default.

To configure this, I [read the documentation](https://docs.spring.io/spring-session/reference/guides/boot-jdbc.html) and had to do a few things to get it working:
- **Change the session resolving mechanism**, by default, sessions are set/read using cookies, we want them to be resolved from a HTTP header.
- **Create the session tables**, by default, Spring Session will manage your database tables, but I'd like to manage them myself using our own database migrations (and change the names)
- **Set some Spring Session config in application.properties**, I used [this link](https://docs.spring.io/spring-boot/docs/2.4.x/reference/html/appendix-application-properties.html#spring.session.jdbc.initialize-schema) as a reference. I changed the session expiry time, the table names, and the automatic session table creation behaviour.

### Testing out Spring Session

Once done, I created two endpoints:
- `/`, this endpoint creates a session
- `/me`, this endpoint reads data from the current session

```java
static class SessionContents {
    private final String testing;
    private final String testing2;

    public SessionContents(Object testing, Object testing2) {
        this.testing = (String)testing;
        this.testing2 = (String)testing2;
    }

    public String getTesting() {
        return testing;
    }

    public String getTesting2() {
        return testing2;
    }
}

@GetMapping("/")
public String home(HttpSession session) {
    session.setAttribute("testing", "1234");
    session.setAttribute("testing2", "{\"foo\": \"bar\"}");
    return "{}";
}

@GetMapping("/me")
public SessionContents me(HttpSession session) {
    return new SessionContents(session.getAttribute("testing"), session.getAttribute("testing2"));
}
```

Using cURL, I called the `/` endpoint, which returned (other headers omitted):

```
$ curl -v http://localhost:8080/

< HTTP/1.1 200 
< ....
< X-Auth-Token: 1c7ebf74-af2c-4699-b1dd-2a1e396b0120
< ...
```

Then I made a second request to `/me` with the `X-Auth-Token` header:

```
$ curl -v --header "X-Auth-Token: 1c7ebf74-af2c-4699-b1dd-2a1e396b0120" http://localhost:8080/me

{"testing":"1234","testing2":"{\"foo\": \"bar\"}"}
```

Now we have sessions working and are able to add arbitary data to a `HttpSession`, we can configure Spring Security.

### Installing Spring Security

We add the following to our `pom.xml`:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>
```

### Configuring Spring Security

Spring Security has [some pretty extensive documentation](https://docs.spring.io/spring-security/reference/servlet/getting-started.html) which I read to configure it. It's great that it describes its architecture in detail, but at times I felt like there was too much information, coupled with my inexperience using the library, it was quite frustrating.

As with many Spring libraries, searching for information online can be frustrating, there are so many versions of Spring, and Spring Security that many times you're reading something only to find out it's for an older version, and now there's a newer, easier way to achieve the same thing.

I finally got it working how I wanted to, which I'll describe in detail below - this took a lot of trial and error, reading of documentation and examining logs. I did not arrive at this result immediately. I'm not going to go into detail on how the different parts of Spring Security work together - maybe I'll write another post on that in the future for my own sake.

Firstly I had to create `SecurityConfig.java`, this is where I define Spring Security's config:

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {
    
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            // Disable CSRF
            .csrf(AbstractHttpConfigurer::disable)
            // Turn off "saved request" logic - this prevents sessions being created when trying to access protected routes without an auth token
            .requestCache(RequestCacheConfigurer::disable)
            // Require certain HTTP requests to require auth
            .authorizeHttpRequests(authorize ->
                authorize
                    // Allow anyone to visit /api/v1/auth/login
                    .requestMatchers("/api/v1/auth/login").permitAll()
                    // For every other URL, require authentication
                    .anyRequest().authenticated()
            )
            .sessionManagement(session -> {
                // Only create a HttpSession when required
                session.sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED);
            });

        return http.build();
    }

    // Provide a custom mechanism for looking up User objects
    @Bean
    public AuthenticationManager authenticationManager(UserDetailsService userDetailsService) {
        DaoAuthenticationProvider authenticationProvider = new DaoAuthenticationProvider();
        authenticationProvider.setUserDetailsService(userDetailsService);
        return new ProviderManager(authenticationProvider);
    }

    // Store the 'SecurityContext' in the HttpSession between requests
    @Bean
    public SecurityContextRepository securityContextRepository() {
        return new HttpSessionSecurityContextRepository();
    }

}
```

In this config we use a custom `UserDetailsService`, which is what Spring Security uses to lookup `User`s, ours is defined like this:

```java
@Service
public class CustomUserDetailsService implements UserDetailsService {
    private final UserDao userDao;

    @Autowired
    public CustomUserDetailsService(UserDao userDao) {
        this.userDao = userDao;
    }

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        User user = userDao.findByEmail(username);
        if(user == null) {
            throw new UsernameNotFoundException("Username not found");
        }
        return new org.springframework.security.core.userdetails.User(user.getEmail(), user.getPassword(), Collections.emptyList());
    }
}
```

It's really simple, it uses jOOQ to fetch a `User` from the DB by email (instead of username). We use Spring Security's own implementation of `UserDetails` (`org.springframework.security.core.userdetails.User`).

Next I had to write my `/api/v1/auth/login` endpoint:

```java
@RestController
public class AuthController {
    private final AuthenticationManager authenticationManager;
    private final SecurityContextRepository securityContextRepository;
    private final SecurityContextHolderStrategy securityContextHolderStrategy = SecurityContextHolder.getContextHolderStrategy();

    @Autowired
    public AuthController(
            AuthenticationManager authenticationManager,
            SecurityContextRepository securityContextRepository) {
        this.authenticationManager = authenticationManager;
        this.securityContextRepository = securityContextRepository;
    }

    // todo: Return proper request/response types instead of JSON strings
    @PostMapping("/api/v1/auth/login")
    public String handleLogin(
            @RequestBody LoginRequest loginRequest,
            HttpServletRequest req,
            HttpServletResponse res) {

        UsernamePasswordAuthenticationToken authentication =
            UsernamePasswordAuthenticationToken.unauthenticated(loginRequest.email(), loginRequest.password());

        try {
            // This calls 'CustomUserDetailsService' under the hood and checks the plain-text password against the hashed password contained
            // on the user record.
            // If the user doesn't exist (email doesn't match) or the password is incorrect, it will throw an exception.
            Authentication response = authenticationManager.authenticate(authentication);

            // Here we manually add the authentication to 'SecurityContext' 
            SecurityContext context = securityContextHolderStrategy.createEmptyContext();
            context.setAuthentication(response);
            securityContextHolderStrategy.setContext(context);

            // Finally we persist the `SecurityContext` to the HttpSession
            securityContextRepository.saveContext(context, req, res);
            return "{\"success\": true}";
        } catch (AuthenticationException ex) {
            // Authentication failed, don't save anything to the HttpSession
            return "{\"error\": \"Wrong credentials\"}";
        }
    }

    public record LoginRequest(String email, String password) {}
}
```

This isn't finished, but demonstrates the basic idea. We don't use Spring Security's built-in mechanisms for authenticating users (form login, HTTP basic auth), we do it manually, [as described in their docs](https://docs.spring.io/spring-security/reference/servlet/authentication/session-management.html#store-authentication-manually).

The result of this is that the authenticated user gets saved to the `SPRING_SESSION` table and subsequent requests with that session ID (through the `X-Auth-Token` header) will give us access to the authenticated user's details.

### Testing out Spring Security

Let's make sure everything is working how we expect it to. In our `user` table we have the following user:
```
email               | password
------------------------------
danmofo@gmail.com   | <hashed_password>
```

First, let's try and authenticate with invalid credentials (wrong password):

```bash
$ curl -v --header "Content-Type: application/json" --data '{"email":"danmofo@gmail.com","password":"passwo"}' http://localhost:8080/api/v1/auth/login

{"error": "Wrong credentials"}
```

We also check the Spring Session table, and see that it hasn't created a row, this means that unsuccessful authorisation attempts do not needlessly create session records.

Now let's try and authenticate with valid credentials:

```bash
$ curl --header "Content-Type: application/json" --data '{"email":"danmofo@gmail.com","password":"password"}' http://localhost:8080/api/v1/auth/login

# Headers:
< X-Auth-Token: e3dc1ba6-bd62-4cd6-b077-6f26def4e0a9
 
# Response
{"success": true}
```

We can see it's returned a success response, and a header containing our session token. We then check the Spring Session table, and see that it's created a row, with our authenticated user details inside:

```bash
|PRIMARY_ID                          |SESSION_ID                          |CREATION_TIME    |LAST_ACCESS_TIME |MAX_INACTIVE_INTERVAL|EXPIRY_TIME      |PRINCIPAL_NAME   |
|------------------------------------|------------------------------------|-----------------|-----------------|---------------------|-----------------|-----------------|
|101db7e6-335b-4802-aeeb-63000c81b9ff|e3dc1ba6-bd62-4cd6-b077-6f26def4e0a9|1,720,611,678,696|1,720,611,678,696|86,400               |1,720,698,078,696|danmofo@gmail.com|
```

The last thing we want to test is accessing a protected route with both a valid and an invalid token.

The controller looks like this:

```java
@RestController
public class UserDetailController {
    @GetMapping("/auth")
    public String protectedRoute(@AuthenticationPrincipal User user) {
        return "{\"user\": \"" + user.getUsername() + "\"}";
    }
}
```

Let's make a request with a valid token:

```
$ curl --header "x-auth-token: e3dc1ba6-bd62-4cd6-b077-6f26def4e0a9" http://localhost:8080/auth

{"user": "danmofo@gmail.com"}
```

And with an invalid token:

```
$ curl -v --header "x-auth-token: fads" http://localhost:8080/auth

< HTTP/1.1 403
```

This works! Checking our Spring Session table, and we can see it hasn't created any new rows. In the `DEBUG` logs I could see it's redirecting to some `/error` endpoint, which we don't want it to do (as it then performs a bunch of additional logic), but we can sort that out later on.

### Writing some integration tests

Now we've got a basic example working, and we've tested it manually, we'll write some integration tests to validate it works, should we want to change anything in the future.

I created an integration test like so:

```java
@SpringBootTest
@AutoConfigureMockMvc
class AuthControllerLoginIntegrationTest {
    @Autowired private MockMvc mockMvc;
    @Autowired private DSLContext db;

    /**
     * This tests a few things after authenticating:
     * - Session token is set in X-Auth-Token header
     * - Session is saved to the database
     * - Session in database contains the user that's authenticated
     */
    @Test
    void shouldReturnSessionTokenInHeaderAndCreateSessionAfterAuthentication() throws Exception {
        MvcResult result = this.mockMvc.perform(loginRequest("danmofo@gmail.com", "password"))
                .andExpect(status().isOk())
                .andExpect(header().exists("X-Auth-Token"))
                .andExpect(jsonPath("$.success").value(true))
                .andReturn();

        // Grab the session ID from the response header.
        String sessionId = result.getResponse().getHeader("X-Auth-Token");

        // Check it got saved in the DB
        String emailSavedInSession = findPrincipalForSessionId(sessionId);
        assertEquals("danmofo@gmail.com", emailSavedInSession);
    }

    private String findPrincipalForSessionId(String sessionId) {
        String emailSavedInSession = db.selectFrom(SPRING_SESSION)
            .where(SPRING_SESSION.SESSION_ID.eq(sessionId))
            .fetchOne(SPRING_SESSION.PRINCIPAL_NAME);

        // Remove the record
        db.delete(SPRING_SESSION)
            .where(SPRING_SESSION.SESSION_ID.eq(sessionId))
            .execute();

        return emailSavedInSession;
    }

    private MockHttpServletRequestBuilder loginRequest(String email, String password) throws JsonProcessingException {
        ObjectMapper mapper = new ObjectMapper();
        AuthController.LoginRequest request = new AuthController.LoginRequest(email, password);

        return post("/api/v1/auth/login")
            .contentType(MediaType.APPLICATION_JSON)
            .content(mapper.writeValueAsString(request));
    }
}
```

This works but has a few problems (which we can resolve at a later date):
1. It requires the database to have some existing state (in this case, a user with the email danmofo[at]gmail.com)
2. We have to manually remove the created sessions from the session table afterwards to stop it cluttering up our dev database

I thought I could deal with these problems as usual by wrapping the test method in `@Transactional`, causing all SQL operations to be rolled back at the end of the test, but had issues with jOOQ "seeing" the session records (when I queried the session table, there were none there, despite the session being created). Spring Session manages sessions in its own transaction (`REQUIRES_NEW`), so maybe that's got something to do with it.

I didn't spend any more time investigating this (maybe something for the future), and carried on writing more tests.

This makes sure that an email and password are provided:

```java
@Test
void shouldReturnErrorWhenCredentialsMissing() throws Exception {
    this.mockMvc.perform(loginRequest(null, null))
        .andExpect(status().is4xxClientError())
        .andExpect(jsonPath("$.errorCode").value(ErrorCode.VALIDATION.toString()))
        .andExpect(jsonPath("$.validationErrors.length()").value(2))
        .andExpect(jsonPath("$.validationErrors[*].field", containsInAnyOrder("email", "password")))
        .andDo(print());
}
```

Our controller method signature needed to be updated to this to validate the request:

```java
@PostMapping("/api/v1/auth/login")
public String handleLogin(
        @Valid @RequestBody LoginRequest loginRequest,
        HttpServletRequest req,
        HttpServletResponse res) {}
```

...and we had to add some annotations to our `LoginRequest` model:

```java
public record LoginRequest(
        @NotEmpty String email,
        @NotEmpty String password) {}
```

Now when validation fails, Spring will throw a `MethodArgumentNotValidException`, we can handle this in a global fashion by creating a `ErrorHandler` class like so:

```java
@ControllerAdvice
public class ErrorHandler {

    @ResponseStatus(HttpStatus.BAD_REQUEST)
    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseBody
    public ValidationErrorResponse handleValidationExceptions(MethodArgumentNotValidException ex) {
        List<ValidationError> validationErrors = ex.getBindingResult().getAllErrors().stream()
            .map(error ->
                new ValidationError(((FieldError) error).getField(), error.getDefaultMessage())
            )
            .toList();

        return new ValidationErrorResponse(validationErrors);
    }
}
```

This maps `BindingResult`s field/error messages to a `ValidationErrorResponse` and returns it as JSON to the client:

```json
{
    "errorCode": "VALIDATION",
    "validationErrors": [
        {
            "field": "email",
            "message": "must not be empty"
        },
        {
            "field": "password",
            "message": "must not be empty"
        }
    ]
}
```

Let's write a test to make sure that an error is returned when the email does not match:

```java
@Test
void shouldReturnErrorWhenEmailDoesNotMatchAnyUserRecords() throws Exception {
    this.mockMvc.perform(loginRequest("i-do-not-exist@gmail.com", "password"))
        .andExpect(status().is4xxClientError())
        .andExpect(jsonPath("$.error").value("Wrong credentials"))
        .andDo(print());
}
```

This fails because currently, our controller is returning a 200 status code, regardless of the authenticatino outcome.

To change that, we can modify our controller signature again:

```java
    @PostMapping("/api/v1/auth/login")
    public ResponseEntity<ApiResponse> handleLogin(
            @Valid @RequestBody LoginRequest loginRequest,
            HttpServletRequest req,
            HttpServletResponse res) {}
```

We now return a `ResponseEntity<ApiResponse>`. A `ResponseEntity` can have a status code and a body, and it gets serialised as JSON by Spring. We cannot just annotate our method with a `@ResponseStatus` as it needs return a different status code in different circumstances.

Because we need to return two different types in our method, `LoginSuccessResponse` when authentication is successful and `ErrorResponse` when it fails, we use a common parent interface `ApiResponse` as the return type of our controller - `ResponseEntity<ApiResponse>`. We can now return anything that implements that interface, and our code will still compile.

Now we've done that, let's write our final test:

```java
@Test
void shouldReturnErrorWhenPasswordDoesNotMatchUsersPassword() throws Exception {
    this.mockMvc.perform(loginRequest("danmofo@gmail.com", "wrong-password"))
        .andExpect(status().is4xxClientError())
        .andExpect(jsonPath("$.errorCode").value(ErrorCode.INVALID_CREDENTIALS.toString()))
        .andDo(print());
}
```

This is pretty much identical to the previous test.

> **Side note**, you may notice by looking at my tests that I'm testing things indirectly (the authentication service for example). This is intentional - we want to make sure all of the different parts work together.

## Conclusion

Setting up jOOQ, Spring Session and Spring Security took much longer than I was anticipating, but now I feel much more comfortable setting them up.

In the next part we'll start building the individual API endpoints needed by our app.

[Bye for now](https://www.youtube.com/watch?v=JgFvNzLAWtY)