---
layout: '@layouts/BlogLayout.astro'
title: 'Part three - Building a fitness tracking app with Java'
pubDate: 2024-07-10
description: 'How I built a fitness tracking app using Java, MySQL, React Native and more.'
draft: true
---

- [What we're going to work on](#what-were-going-to-work-on)
- [Building endpoints](#building-endpoints)
  - [Start workout](#start-workout)
  - [Log exercise for workout](#log-exercise-for-workout)
- [Refactoring: Spring Security User](#refactoring-spring-security-user)
- [Building more endpoints](#building-more-endpoints)
- [Conclusion](#conclusion)

## What we're going to work on

As mentioned in [part two](/writing/2024/07/building-a-fitness-app-with-java-part-2), we're going to start building the individual endpoints that make up our API - finally we get to actually write something useful 😊

## Building endpoints

Most endpoints are going to follow the same general process:
- Write some request/response classes
- Write a controller method that accepts our request class, and returns our response class
- Write a service method that does something useful, with some associated tests
- If necessary, write some tests for:
  - **Controller**, to ensure it validates the request, and returns the correct response
  - **Service**, these tests will use mocked DAOs
  - **DAO**, these tests will be against a real database, to make sure our queries are working as intended.

If I wasn't trying to build this as fast as possible, I'd write an OpenAPI spec at this point, and generate the backend/frontend code from that.

Based on our [application flow](http://localhost:4321/writing/2024/07/building-a-fitness-app-with-java-part-1#designing-the-app-flow), the first thing we'll need to build is the **start workout endpoint**

### Start workout

This endpoint will be called when the user wants to start their workout. 

We'll map it to `POST /api/v1/workout/` ,

First we create the controller method:

```java
  @PostMapping("/api/v1/workout/")
  public ResponseEntity<ApiResponse> handleCreateWorkout(@AuthenticationPrincipal User user) {
      Workout workout = workoutService.createWorkout(user);
      return ResponseEntity.ok(new CreateWorkoutResponse(workout.getId()));
  }
```

Pretty basic stuff. In our service we have:

```java
public Workout createWorkout(User user) {
    com.dmoffat.fitnesstracker.model.User owner = userDao.findByEmail(user.getUsername());
    return workoutDao.create(owner.getId());
}
```

This method takes a Spring Security `User` (which is why we have fully qualified our `User`). 

Finally, in our DAO:

```java
public Workout create(Integer ownerUserId) {
    WorkoutRecord workout = db.newRecord(WORKOUT);
    workout.setUserId(UInteger.valueOf(ownerUserId));
    workout.setStartedOn(LocalDateTime.now());
    workout.setCreatedOn(LocalDateTime.now());
    workout.store();

    return workout.into(Workout.class);
}
```

This is really basic stuff, the service layer is barely doing anything. Now we have to write our integration test, which is slightly more involved.

If you remember, our endpoints all require a session token to access, so our test will need to somehow obtain one before making a request with it. To do this, I first make a request to the `/api/v1/auth/login` endpoint before using that token in the next request, it looks like this:

```java
@Test
@Transactional
void shouldReturnCorrectResponseWhenWorkoutCreated() throws Exception {
    mockMvc.perform(authenticatedRequest("/api/v1/workout/"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.workoutId").isNotEmpty());
}

private String createSessionId() throws Exception {
    logger.info("Creating session ID");
    ObjectMapper mapper = new ObjectMapper();
    mapper.setSerializationInclusion(JsonInclude.Include.NON_NULL);

    AuthController.LoginRequest loginRequest = new AuthController.LoginRequest("danmofo@gmail.com", "password");

    MockHttpServletRequestBuilder request = post("/api/v1/auth/login")
        .contentType(MediaType.APPLICATION_JSON)
        .content(mapper.writeValueAsString(loginRequest));

    return mockMvc.perform(request).andReturn().getResponse().getHeader("X-Auth-Token");
}

private MockHttpServletRequestBuilder authenticatedRequest(String endpoint) throws Exception {
    String sessionId = createSessionId();
    logger.debug("Performing authenticated request to: " + endpoint + " with session ID: " + sessionId);
    return post(endpoint)
        .header("X-Auth-Token", sessionId);
}
```

We've now got a useful method named `authenticatedRequest` which creates a session token, and calls the endpoint with it. 

There's one small problem however (mentioned in my last post too), the records added to the `SPRING_SESSION` tables do not get rolled back at the end of the test, meaning our test database gets filled up with sessions each time our test runs.

After turning on `TRACE` logging, I managed to figure out what was happening, and wrote the following config `@Bean`, the comment describes WHY it's needed:

```java
/***
 * This disables Spring Session's transactional behaviour.
 *
 * Why do we need to do this?
 * When running tests with @Transactional, changes made by Spring Session are not rolled back, as the transaction
 * is performed with propagation set to {@link org.springframework.transaction.annotation.Propagation#REQUIRES_NEW}.
 * 
 * https://docs.spring.io/spring-framework/docs/2.5.3/reference/transaction.html
 *
 * This means that the transaction started during test method execution is suspended, a new transaction is opened,
 * Spring session does its thing, then the transaction is committed, meaning the changes it makes never get rolled
 * back (because they are different transactions). This results in a bunch of SPRING_SESSION records being created 
 * and left in the DB.
 */
@Bean("springSessionTransactionOperations")
public TransactionOperations springSessionTransactionOperations() {
    System.out.println("################################################");
    System.out.println("## Disabling transactions for Spring Session. ##");
    System.out.println("################################################");
    return TransactionOperations.withoutTransaction();
}
```

After adding this the session table inserts get rolled back. As a bonus, our previous test `AuthControllerLoginIntegrationTest` no longer needs to manually delete session records!

We've now finished this endpoint, and it has an integration test to make sure it works. The service and DAO are so simple, I don't think it's worth writing any tests for those at this stage.

### Log exercise for workout

This endpoint will be called when the user wants to log an exercise for their workout.

We'll map it to `POST /api/v1/workout/{workoutId}/exercise/`.

Before writing the controller, let's think about the request body for a second.

We'll need to know the `workout_id` to add the exercise to, the `exercise_id` that describes the type of exercise being performed, plus all the other data for the exercise:

```json
{
    "workoutId": 1234,
    "exerciseId": 1234,
    "weight": 100,
    "sets": 1,
    "reps": 5,
    "notes": "This was really difficult."
}
```

Let's write the controller method:

```java
@PostMapping("/api/v1/workout/{workoutId}/exercise/")
public ResponseEntity<ApiResponse> handleLogExercise(
        @RequestBody @Valid LogExerciseRequest request,
        @AuthenticationPrincipal User user) {
    
    logExerciseService.logExercise(user, request);

    return ResponseEntity.ok(null);
}
```

This currently doesn't do anything useful (the service method is empty and it doesn't return anything), let's write the implementation.

Our service needs to do a few things:

1. Make sure the given user owns the workout they're trying to log an exercise for
2. Add a record to `ft.workout_exercise`
3. If the exercise is the same weight, reps and equipment as an existing record, merge the two records together. Let me try and explain:
   1. User logs a squat for 1 set and 5 reps of 100KG
   2. User logs another squat for 1 set and 5 reps of 100KG
   3. These records will be combined into a single record of 2 sets of 5 reps of 100KG.

I debated whether to add this "feature", but I think it would be useful to combine duplicates - we can always remove it later on if needed.

I wrote the following:

```java
public WorkoutExercise logExercise(User workoutOwner, LogExerciseRequest request) {
    logger.debug("Logging exercise for: " + workoutOwner.getUsername());

    logger.debug("Fetching workout (" + request.workoutId() + ") w/ User");
    var workout = workoutDao.findOneWithUser(request.workoutId());

    // Does the workout exist?
    if (workout == null) {
        logger.debug("Workout does not exist.");
        return null;
    }

    // Is it the user's workout? Do they have permission?
    if(!workout.getUser().getEmail().equals(workoutOwner.getUsername())) {
        logger.debug("User does not own the workout");
        return null;
    }

    // Does the exercise exist?
    logger.debug("Fetching exercise (" + request.exerciseId() + ")");
    var exercise = exerciseDao.findOne(request.exerciseId());
    if (exercise == null) {
        logger.debug("Exercise does not exist");
        return null;
    }

    // Assemble the workout exercise to create
    var workoutExercise = new WorkoutExercise();
    workoutExercise.setWorkout(workout);
    workoutExercise.setExercise(exercise);
    workoutExercise.setWeight(request.weight());
    workoutExercise.setReps(request.reps());
    workoutExercise.setSets(request.sets());
    workoutExercise.setNotes(request.notes());
    workoutExercise.setEquipment(request.equipment());
    workoutExercise.setCreatedOn(LocalDateTime.now());

    // Find any matching records in the same workout, with the same weight, reps and equipment
    var duplicate = workoutExerciseDao.findByWorkoutExerciseIdWeightRepsAndEquipment(workoutExercise);
    if (duplicate == null) {
        logger.debug("This is a brand new workout exercise.");
        return workoutExerciseDao.create(workoutExercise);
    }

    logger.debug("This exercise has already been performed before, incrementing sets.");
    workoutExercise.setSets(duplicate.getSets() + 1);
    workoutExerciseDao.updateSets(duplicate.getId(), duplicate.getSets());

    return workoutExercise;
}
```

You may notice that we check if the exercise exists, which is not necessary due to our foreign key on the `workout_exercise` table, if the exercise doesn't exist, the insert will fail, however it means our `WorkoutExercise` object has fully populated associations instead of ID fields.

Also notice the `WorkoutDao#findOneWithUser` method, which fetches the workout and its associated user:

```java
public Workout findOneWithUser(Integer id) {
    return db.select()
        .from(WORKOUT)
        .join(WORKOUT.user())
        .where(WORKOUT.ID.eq(UInteger.valueOf(id)))
        .fetchOne(record -> {
            User user = new User();
            user.setId(record.get(USER.ID).intValue());
            user.setEmail(record.get(USER.EMAIL));
            
            Workout workout = new Workout();
            workout.setId(record.get(WORKOUT.ID).intValue());
            workout.setUser(user);
            return workout;
        });
}
```

jOOQ doesn't provide a nice way to map objects in your model, it only maps nicely when fields in the record and your POJO match exactly, so we have to do that manually. I get the impression we'll end up writing quite a bit of mapping code like this to map between our domain models and our DB models.

> **Side note**: the reason we're doing the mapping is to stop jOOQ leaking into our services. If we decide it's not worth it, we'll just remove that level of indirection. At this point, it feels like most of the effort is just mapping between jOOQ models and our domain models.

Now we need to write some unit tests for this method to make sure it works. We'll use Mockito to mock our DAOs and make them return fixed responses, so we can control the output of the service without needing to put specific things in our database. 

Our first test makes sure that can't log an exercise for a workout that doesn't exist (note: I realised without my IDE, the `LogExerciseRequest` creation is really unreadable! The IDE adds field names next to each one):

```java
@Test
void shouldNotLogExerciseForNonExistentWorkout() {
    var request = new LogExerciseRequest(
        1, // Workout ID - This doesn't exist
        1,
        100,
        1,
        3,
        "Do something",
        null
    );

    WorkoutExercise result = logExerciseService.logExercise(new User(), request);
    assertNull(result);
}
```

Our next text makes sure you can't log an exercise for a workout you didn't create:

```java
@Test
void shouldNotLogExerciseForIfUserDoesntOwnWorkout() {
    // Create a workout belonging to someone else
    var workout = new Workout();
    workout.setUser(new User(2));
    when(workoutDao.findOneWithUser(1)).thenReturn(workout);

    var user = new User(1);
    var request = new LogExerciseRequest(
        1, // Workout ID - User doesn't own this
        1,
        100,
        1,
        3,
        "Do something",
        null
    );

    WorkoutExercise result = logExerciseService.logExercise(user, request);
    assertNull(result);
}
```

Our next test makes sure an exercise gets logged:

```java
    @Test
    void shouldLogNewExerciseIfNotADuplicateWithSameIdWeightRepsAndEquipment() {
        // Create a workout belonging to user
        var user = new User(1);
        var workout = new Workout(1);
        workout.setUser(user);
        when(workoutDao.findOneWithUser(1)).thenReturn(workout);

        // Create an exercise
        var exercise = new Exercise(1);
        when(exerciseDao.findOne(1)).thenReturn(exercise);

        // Mock #create to return a fixed value
        when(workoutExerciseDao.create(any(WorkoutExercise.class))).thenReturn(1);

        var request = new LogExerciseRequest(
            1, // Workout ID
            1, // Exercise ID
            100, // Weights
            1, // Sets
            3, // Reps
            "My notes",
            List.of("BELT")
        );

        WorkoutExercise result = logExerciseService.logExercise(user, request);
        assertEquals(1, result.getId());
        assertEquals(1, result.getWorkout().getId());
        assertEquals(1, result.getExercise().getId());
        assertEquals(100, result.getWeight());
        assertEquals(1, result.getSets());
        assertEquals(3, result.getReps());
        assertEquals("My notes", result.getNotes());
        assertEquals(List.of("BELT"), result.getEquipment());
        assertNotNull(result.getCreatedOn());
    }
```

And our final test makes sure that if the exercise is a duplicate of another (that is, an exercise with the same workout, weight, reps and equipment), it increments the `sets` value:

```java
@Test
void shouldUpdateExistingExerciseIfDuplicateWithSameIdWeightRepsAndEquipment() {
    // Create a workout belonging to user
    var user = new User(2);
    var workout = new Workout(1);
    workout.setUser(user);
    when(workoutDao.findOneWithUser(1)).thenReturn(workout);

    // Create an exercise
    var exercise = new Exercise(1);
    when(exerciseDao.findOne(1)).thenReturn(exercise);

    // Create a duplicate - this should have its sets incremented
    var initialSets = 1;
    var duplicate = new WorkoutExercise(1);
    duplicate.setSets(initialSets);
    when(workoutExerciseDao.findByWorkoutExerciseIdWeightRepsAndEquipment(any(WorkoutExercise.class)))
        .thenReturn(duplicate);

    var request = new LogExerciseRequest(
        1, // Workout ID
        1, // Exercise ID
        100, // Weights
        1, // Sets
        3, // Reps
        "My notes",
        List.of("BELT")
    );

    WorkoutExercise result = logExerciseService.logExercise(user, request);
    assertEquals(initialSets + 1, result.getSets());
}
```
We've now guaranteed that our service will return the correct result if the DAOs return what they're supposed to. The next part is writing some integration tests to make sure the individual DAO methods do what they're supposed to. If we know the DAOs return the correct results, and we know the service returns the correct result given these DAOs, then we can be fully confident that our system behaves in the way we want to.

In the initial prototyping stage tests like this have less value as functionality will change often as the requirements become clear.

Now let's write some integration tests for our various DAOs, here's one for `WorkoutDao`:

```java
@Test
@Transactional
void shouldCreateNewWorkout() {
    var workout = workoutDao.create(1);

    // Make sure the record got mapped to our model
    assertEquals(1, workout.getUser().getId());
    assertNotNull(workout.getId());

    // Make sure the workout got added to the database.
    var record = db.selectFrom(WORKOUT)
        .where(WORKOUT.ID.eq(UInteger.valueOf(workout.getId())))
        .fetchOne();

    assertNotNull(record);
    assertNotNull(record.getCreatedOn());
    assertNotNull(record.getStartedOn());
    assertEquals(1, record.getUserId().intValue());
}

@Test
@Transactional
void shouldFindOneWithUser() {
    // Add a record for a user
    var newWorkout = workoutDao.create(1);

    // Now fetch it
    var workout = workoutDao.findOneWithUser(newWorkout.getId());
    var user = workout.getUser();

    // Make sure our model was mapped
    assertEquals(1, user.getId());
    assertEquals("danmofo@gmail.com", user.getEmail());
    assertEquals(newWorkout.getId(), workout.getId());
}
```

Pretty simple stuff. You might noticed that we're relying on some existing state in the DB. We're planning to solve this later on with the use of [TestContainers](https://testcontainers.com/). The other not so great thing is that we are using a DAO method to populate the database in our second test, which means it may fail if `#create` stops working, giving us a false positive - I was just being lazy here.

Here's one for `ExerciseDao`:

```java
@Test
void shouldFindOneById() {
    var exercise = exerciseDao.findOne(1);

    assertNotNull(exercise);
    assertEquals(1, exercise.getId());
    assertEquals("Back squat", exercise.getName());
    assertNull(exercise.getBrand());
    assertEquals("FREE_WEIGHT", exercise.getType().toString());
}
```

Again, pretty simple stuff, but relies on some existing DB state.

Finally, here's one for `WorkoutExerciseDao`:

```java
@Test
@Transactional
void shouldUpdateSets() {
    // Prepare
    var workout = db.newRecord(WORKOUT);
    workout.setUserId(UInteger.valueOf(1));
    workout.setStartedOn(LocalDateTime.now());
    workout.setCreatedOn(LocalDateTime.now());
    workout.store();

    var workoutExercise = db.newRecord(WORKOUT_EXERCISE);
    workoutExercise.setExerciseId(UInteger.valueOf(1));
    workoutExercise.setWorkoutId(workout.getId());
    workoutExercise.setWeight(UInteger.valueOf(100));
    workoutExercise.setReps(5);
    workoutExercise.setSets(1);
    workoutExercise.setCreatedOn(LocalDateTime.now());
    workoutExercise.store();

    // Execute
    workoutExerciseDao.updateSets(workoutExercise.getId().intValue(), 2);

    // Test
    var savedRecord = findWorkoutExerciseRecord(workoutExercise.getId());
    assertEquals(2, savedRecord.getSets());
}

@Test
@Transactional
void shouldCreateNewWorkoutExercise() {
    // Prepare
    var workout = workoutDao.create(1);
    workout.setUser(new User(1));
    var workoutExercise = new WorkoutExercise();
    workoutExercise.setWorkout(workout);
    workoutExercise.setExercise(new Exercise(1));
    workoutExercise.setEquipment(List.of("BELT", "SOMETHING_ELSE"));
    workoutExercise.setWeight(100);
    workoutExercise.setReps(5);
    workoutExercise.setSets(1);
    workoutExercise.setNotes("This is a note");

    // Execute
    Integer id = workoutExerciseDao.create(workoutExercise);

    // Test
    var savedRecord = findWorkoutExerciseRecord(UInteger.valueOf(id));
    assertEquals("[\"BELT\", \"SOMETHING_ELSE\"]", savedRecord.getEquipment().data());
    assertEquals(workout.getId(), savedRecord.getWorkoutId().intValue());
    assertEquals(1, savedRecord.getExerciseId().intValue());
    assertEquals(100, savedRecord.getWeight().intValue());
    assertEquals(5, savedRecord.getReps());
    assertEquals(1, savedRecord.getSets());
    assertEquals("This is a note", savedRecord.getNotes());
    assertNotNull(savedRecord.getCreatedOn());
}
```
You can see from this how much code is being written to get the database into a state we require, it would be much easier to write some SQL to do that before our test runs.

The final two tests caused me some issues:

```java
@Test
@Transactional
void findByWorkoutExerciseIdByWeightRepsAndEquipmentWithEquipment() {
    // Prepare
    var workoutExercise = createWorkoutExerciseWithEquipment(List.of("BELT", "SOMETHING_ELSE"));

    // Execute
    var result = workoutExerciseDao.findByWorkoutExerciseByWeightRepsAndEquipment(workoutExercise);
    assertNotNull(result);
}

@Test
@Transactional
void findByWorkoutExerciseIdByWeightRepsAndEquipmentWithoutEquipment() {
    // Prepare
    var workoutExercise = createWorkoutExerciseWithEquipment(null);

    // Execute
    var result = workoutExerciseDao.findByWorkoutExerciseByWeightRepsAndEquipment(workoutExercise);
    assertNotNull(result);
}
```

This method (`findByWorkoutByWeightRepsAndEquipment`) is used to find duplicate workout exercises so they can be merged together.

I had a lot of trouble writing a query that could fetch a row by its equipment. My inital attempt was something like:

```java
db.selectFrom(WORKOUT_EXERCISE)
    .where(WORKOUT_EXERCISE.EQUIPMENT.eq(toJson(equipmentToFind)))
```

To my surprise this didn't work. When I printed out the value of the JSON in the DB, and the JSON produced by `toJson()`, I noticed there was a space after the comma:

```js
// In the DB
["BELT", "KNEE_SLEEVES"]

// My string I was searching for
["BELT","KNEE_SLEEVES"]
```

Initially I thought that I must've been inserted it incorrectly but nope, as it turns out, MySQL adds that space after the comma...

I could not find a way in the jOOQ docs to deal with this problem, so I had to resort to raw SQL:

```java
db.selectFrom(WORKOUT_EXERCISE)
    .where("equipment = JSON_ARRAY(" + toQuotedStringList(workoutExercise.getEquipment()) + ")")
```

Which produces the following SQL:

```sql
WHERE equipment = JSON_ARRAY('BELT', 'KNEE_SLEEVES')
```

What a nightmare! In general I've found working with JSON columns in jOOQ a bit tricky - maybe I should've stored them in another table - I did it this way for simplicity.

Now that we've tested the service and the DAOs, we'll need to write a final integration test to make sure that our controller returns the correct responses:

```java
// todo
```

Everything is now tested properly - I think we spent longer writing the tests to make sure it works than actually writing the code we tested. In the future I'll skip adding test code to these posts unless there's something particularly interesting about them.

## Refactoring: Spring Security User

Whilst i was writing these endpoints, there's one thing I noticed with our implementation of Spring Security which bugged me. We have two models for `User`, one of them is a Spring Security class which implements `UserDetails`, and the other is our own `User` model.

The Spring Security model would be fine if we were using `user.email` as our primary key in the `user` table, but we aren't, we're using the ID. That means in order to set the `user_id` foreign key in our `workout` table, we have to lookup the ID using the user's email. Take a look at this example:

```java
// ... in a controller
public void myControllerMethod(@AuthenicatedPrincipal User springSecurityUserModel) {
    myService.saveWorkout(springSecurityUserModel, new Workout());
}

// ... in the service
public void saveWorkout(User springSecurityUserModel, Workout workout) {
    // Grab the ID for the authenticated user.
    com.dmoffat.fitnesstracker.model.User ourUserModel = userDao.findOneByEmail(springSecurityUserModel.getUsername());
}
```
Every time we need a set a `user_id` foreign key, we'll need to perform this query, so this line of code will end up being pasted around everywhere, it would be easier if Spring Security used our own `User` model.

We're already using a custom `UserDetailsService`, so we just need to return our own `User` model from it like so:

```java
@Override
public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
    var user = userDao.findByEmail(username);
    if(user == null) {
        throw new UsernameNotFoundException("Username not found");
    }
    return user;
}
```

And change our `User` model to implement `UserDetails` and `CredentialsContainer`:

```java
public class User implements UserDetails, CredentialsContainer {
    private Integer id;
    private String email;
    private String password;

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return Collections.emptyList();
    }

    @Override
    public String getUsername() {
        return getEmail();
    }

    @Override
    public void eraseCredentials() {
        this.password = null;
    }

    // ... rest of code ...
}
```

`CredentialsContainer` is not strictly necessary, we implement it so that the `password` isn't kept in memory - it's called by Spring Security after authenticating.

And that's it, we can now change code like this:

```java
public Workout createWorkout(User user) {
    var ownerUser = userDao.findByEmail(user.getUsername());
    return workoutDao.create(ownerUser.getId());
}
```

into something much simpler:

```java
public Workout createWorkout(User user) {
    return workoutDao.create(user.getId());
}
```

And when we fetch the authenticated user in our controller like this:

```java
@GetMapping("/auth")
public String protectedRoute(@AuthenticationPrincipal User user) {
    return "{\"user\": \"" + user.getId() + "\"}";
}
```

It actually returns our own `User` model.

In hindsight, I don't know why I didn't do this in the first place - if there was a reason, I don't remember it. Anyway, back to building those endpoints...

todo: Write about a bug where the user model changes and sessions stop working - can we get around this?

## Building more endpoints




## Conclusion

Some text

In the next part we'll...

[Bye for now](https://www.youtube.com/watch?v=JgFvNzLAWtY)