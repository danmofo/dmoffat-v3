---
layout: '@layouts/BlogLayout.astro'
title: 'Building a fitness tracking app with Java - Part five'
pubDate: 2024-07-22
description: 'How I built a fitness tracking app using Java, MySQL, React Native and more.'
series_posts:
  - name: Part one
    path: /writing/2024/07/building-a-fitness-app-with-java-part-1
  - name: Part two
    path: /writing/2024/07/building-a-fitness-app-with-java-part-2
  - name: Part three
    path: /writing/2024/07/building-a-fitness-app-with-java-part-3
  - name: Part four
    path: /writing/2024/07/building-a-fitness-app-with-java-part-4
  - name: Part five
    path: /writing/2024/07/building-a-fitness-app-with-java-part-5
---

- [What we're going to work on](#what-were-going-to-work-on)
- [Planning](#planning)
- [Building screens](#building-screens)
  - [Layout](#layout)
  - [Initial screen](#initial-screen)
  - [Select exercise screen](#select-exercise-screen)
  - [Exercise summary screen](#exercise-summary-screen)
  - [Add exercise to workout screen](#add-exercise-to-workout-screen)
  - [Workout summary screen](#workout-summary-screen)
  - [Confirmation modal](#confirmation-modal)
  - [Success screen](#success-screen)
- [Conclusion](#conclusion)

## What we're going to work on

As mentioned in [part four](/writing/2024/07/building-a-fitness-app-with-java-part-4), we're going to start working on the main functionality of our app: the log workout screen.

## Planning

Due to the complexity of this part, I'm going to create some wireframes with a pen and paper before I start writing any code - here's what I came up with:

**Start workout screen**

![Start workout screen](../../../../assets/images/fitness-app-article/screen-start-workout.jpg)

**Select exercise screen**

![Select exercise screen](../../../../assets/images/fitness-app-article/screen-select-exercise.jpg)

**Exercise summary screen**

![Exercise summary screen](../../../../assets/images/fitness-app-article/screen-exercise-summary.jpg)

**Add exercise to workout screen**

![Add exercise to workout screen](../../../../assets/images/fitness-app-article/screen-add-exercise-to-workout.jpg)

**Workout summary screen**

![Workout summary screen](../../../../assets/images/fitness-app-article/screen-workout-summary.jpg)


The flow is:
- User clicks start workout on the initial screen
- User is sent to the **select exercise screen**, this is where the user chooses the exercise.
- User is sent to the **exercise summary screen** with the previously selected exercise set as active, this screen contains completed sets for the selected exercise, user clicks the "add set" button to add a new set
- User is sent to the **Add exercise to workout screen**, this is where the user adds the sets, reps, equipment and notes, after finishing, they click "add".
- User is sent back to the **exercise summary screen** with the previously added set displayed in table.
- User can press back to go to the **workout summary screen**, the user can:
  - Add another exercise (which will send the user back to the **select exercise screen**)
  - Add notes to their overall workout
  - View their existing exercises (and edit them if needed)
  - Finish the workout.
- Clicking the finish workout button will prompt the user with a **confirmation modal**, asking them if they want to finish the workout. The initial version won't have a way to edit workouts so we need an additional barrier to stop users accidentally clicking the button.
- After confirming the workout is finished, they'll be shown a **success screen**.

We don't know how this will perform in practice until we actually use it during a workout, but it's a good starting point.

## Building screens

We've already built the APIs that power these screens, so most of the coding we'll do will be writing the screen layouts and talking to our APIs. We'll try and get something minimal working first, and then work on improving it afterwards.

### Layout

First we'll create a separate layout for the log workout process so that we can add a header with a title and a back button. With Expo this is as simple as creating a `_layout.tsx` file in our `log-workout` folder with the following content:

```jsx
import { Stack } from "expo-router";

export default function LogWorkoutLayout() {
    return (
        <Stack>
            <Stack.Screen 
                name="index"
                options={{
                    headerShown: false
                }}
            />
            <Stack.Screen 
                name="select-exercise"
                options={{
                    title: 'Select an exercise'
                }}
            />
            {/* ... other routes go here...*/}
        </Stack>
    )
}
```

### Initial screen

This one is very straightforward, it's a static screen with a big "Start workout" button. Clicking on this button will send a request to our API to start the workout, which will return a `workoutId`. We'll keep track of this ID somewhere then send them on to the next screen.

Let's write a simple screen:

```jsx
export default function LogWorkoutScreen() {
    async function handleStartWorkout() {
        router.navigate("/log-workout/select-exercise");
    }

    return (
        <ScreenLayout screenHasHeader={false}>
            <Box padding={20}>
                <Heading>Log workout</Heading>
                <Button title="START" onPress={handleStartWorkout} />
            </Box>
        </ScreenLayout>
    )
}
```
Then call our API:

```ts
async function handleStartWorkout() {
    const { workoutId } = await startWorkout({ sessionToken });
    if (!workoutId) {
        Alert.alert("Failed to start workout, please try again.");
        return;
    }

    router.navigate("/log-workout/select-exercise");
}
```

Now we have a workout ID, we need to persist it somewhere. I thought of two places that I could store this:
1. In a global store
2. In a path variable, e.g. `/log-workout/{workoutId}/select-exercise`

I decided to put it in a global store for now, not because of any technical reason - simply because that's something I already know how to do.

In our auth store, we persisted data using `expo-secure-store`. Since workout data is not particularly sensitive, let's store it in [AsyncStorage](https://docs.expo.dev/versions/latest/sdk/async-storage/) which is an unencrypted, persistent, key-value store.

We need to install it first:

```bash
npx expo install @react-native-async-storage/async-storage
```

Then write our store:

```ts
import { create } from "zustand";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { createJSONStorage, persist } from "zustand/middleware";

export type WorkoutState = {
    workoutId: number | null,
    startWorkout: (workoutId: number) => void,
    hasWorkoutInProgress: () => void
}

export const useWorkoutStore = create(
    persist<WorkoutState>(
        (set, get) => ({
            workoutId: null,
            startWorkout(workoutId: number) {
                set({ workoutId });
            },
            hasWorkoutInProgress() {
                const { workoutId } = get();
                return workoutId !== null;
            }
        }),
        {
            name: 'workout-storage',
            storage: createJSONStorage(() => AsyncStorage)
        }
    )
);
```

Unlike `expo-secure-store` we don't need to write our own adapter to persist our data - `AsyncStorage` satisfies `StateStorage`s interface.

Then update our event handler to store the workout ID in the store:

```ts
async function handleStartWorkout() {
    const { workoutId } = await startWorkout({ sessionToken });
    if (workoutId === null) {
        Alert.alert("Failed to start workout, please try again.");
        return;
    }

    workoutStore.startWorkout(workoutId!);

    router.navigate("/log-workout/select-exercise");
}
```

One thing which I noticed whilst developing this screen is that when going through the "Start workout" flow, we end up with a bunch of workout IDs for workouts that were started, but not finished. To get around this, when you click "START", we'll check for any workouts that are in progress:

```ts
if (workoutStore.hasWorkoutInProgress()) {
    console.log('Workout already started.');
    router.navigate('/log-workout/select-exercise');
    return;
}
```

In the future, we'll implement some sort of "Resume workout" functionality, but for now, we'll just send them into their workout.

That's it for this screen, we now have the `workoutId` available throughout the process, which we'll need later on to log individual exercises.

### Select exercise screen

This is where the user selects the exercise they want to perform. When the screen loads it will show a list of all exercises, and typing in the search box will filter them. Because the list of exercises is small (< 100), I think we can get away with loading a list of ALL exercises filtering in memory with a primitive text search.

> **Side note:** In the future, we'll improve this by performing the search operations on the server, this will be especially useful as the number of exercises increase.

I realised we don't actually have an endpoint which lists available exercises from our database, so let's write that quickly...

```java
@GetMapping("/api/v1/workout/exercise")
public ResponseEntity<ApiResponse> handleListExercises() {
    List<Exercise> allExercises = exerciseSearchService.search();
    ListExerciseResponse response = new ListExerciseResponse(allExercises);
    return ResponseEntity.ok(response);
}
```

Now that we have that working, let's write the screen itself. We'll need to split this up into 2 different components.

A `SearchBox` for filtering:

```jsx
type SearchBoxProps = {
    query: string,
    onChangeQuery: (newQuery: string) => void
}

export default function SearchBox({ query, onChangeQuery }: SearchBoxProps) {
    function handleClear() {
        onChangeQuery('');
    }

    return (
        <View style={styles.searchBoxContainer}>
            <TextInput
                style={styles.searchBox}
                defaultValue={query}
                onChangeText={onChangeQuery} 
                placeholder="Enter an exercise name..."
            />
            {
                query.length > 0 ?
                <View style={styles.clearButton}>
                    <Text style={styles.clearButtonText} onPress={handleClear}>Clear</Text>
                </View> :
                null
            }
        </View>
    )
}
```

This component doesn't really do much, just propagates the `TextInput`s `onChangeText` event to the parent component.

And an `ExerciseList` for displaying the exercises:

```jsx
type ExerciseListProps = {
    exercises: Exercise[],
    onSelectExercise: (exercise: Exercise) => void
}

export default function ExerciseList({ exercises, onSelectExercise }: ExerciseListProps) {
    if (!exercises) {
        return <Text>Loading exercises...</Text>
    }

    if (exercises?.length === 0) {
        return <Text>No exercises found</Text>;
    }

    return (
        <View style={styles.container}>
            <FlatList
                style={styles.exerciseList}
                data={exercises}
                renderItem={({ item: exercise }) => (
                    <Pressable
                        style={styles.exerciseListItem}
                        onPress={() => onSelectExercise(exercise)}>
                            <Text style={styles.exerciseListItemName}>
                                {exercise.name}
                                {exercise.brand ? `(${exercise.brand})` : null}
                            </Text>
                    </Pressable>
                )}
            />
        </View>
    )
}
```

In the parent component, we'll fetch the list of exercises and provide it as a prop to `ExerciseList` (I could have used `react-query` to fetch the exercises, but for now we'll just do it manually):

```ts
const [exercises, setExercises] = useState<Exercise[]>([]);

useEffect(() => {
    (async () => {
        const response = await listExercises({ sessionToken });
        setExercises(response.exercises);
    })();
}, []);

```

```jsx
<ExerciseList 
    exercises={exercises} 
    onSelectExercise={handleSelectExercise}
/>
```

So now we have a list of exercises displayed, but the search box isn't filtering them, let's filter the list of exercises. We could do this inside the `handleChangeQuery` event handler (which is invoked when the search box's text changes):

```ts
function handleChangeQuery(newQuery: string) {
    setQuery(newQuery);

    const filteredExercises = filterExercises(exercises, newQuery);
    setExercises(filteredExercises);
}
```
However this has a few problems:
1. We lose the original unfiltered list of exercises and would have to create another state variable to hold the filtered list
2. It causes two re-renders, this is unnoticeable to me, but is just unnecessary work that doesn't need to be done.

We can compute the filtered exercises in the component body from the `exercises` and `query` variables (irrelevant code has been removed):

```jsx
export default function SelectExerciseScreen() {    
    const [query, setQuery] = useState<string>('');
    const [exercises, setExercises] = useState<Exercise[]>([]);

    function handleChangeQuery(newQuery: string) {
        setQuery(newQuery);
    }

    // Do it here instead
    const filteredExercises = filterExercises(exercises, query);

    return (
        <ScreenLayout screenHasHeader={false}>
            <Box padding={20}>
                <ExerciseList 
                    exercises={filteredExercises} 
                    onSelectExercise={handleSelectExercise}
                />
            </Box>
        </ScreenLayout>
    )
}
```
Much better.

Our exercise list is looking a bit bare, so at this point I'll update my migration to add a bunch more exercises from my spreadsheet.

The only thing we have left to do now is keep track of the exercise that is currently selected, we can do this by storing it in our workout store after an exercise is selected:


```jsx
const setCurrentExercise = useWorkoutStore(state => state.setCurrentExercise);

function handleSelectExercise(selectedExercise: Exercise) {
    console.log('Selected', selectedExercise);
    setCurrentExercise(selectedExercise);
    router.navigate('/log-workout/exercise-summary');
}
```

### Exercise summary screen

This screen displays a list of completed sets for the currently selected exercise, and the user can also add their sets to the current exercise.

We want the screen's header to be dynamic (display the currently selected exercise's name), which requires us to move the `<Stack.Screen>` component into the route file, so we remove it from `_layout.tsx` and add it to our `exercise-summary.tsx` route:

```jsx
export default function ExerciseSummaryScreen() {
    const workoutStore = useWorkoutStore();
    const router = useRouter();
    const params = useLocalSearchParams()

    useEffect(() => {
        router.setParams({
            title: workoutStore.currentExercise?.name
        });
    }, []);
    
    return (
        <ScreenLayout screenHasHeader={true}>
            <Stack.Screen 
                options={{
                    title: params.title
                }} 
            />
        </ScreenLayout>
    )
}
```

Setting the params must be inside a `useEffect`, as setting it causes a re-render (and in turn, an infinite loop!).

Our page contains two sections:
- A button to send them to the **add exercise to workout screen**
- A table containing completed sets

To display the list of completed sets, we'll need to ask the server for exercises completed with a specific `workout_id` and `exercise_id`. We actually didn't build this endpoint yet (another one I forgot!), so first let's go ahead and write that:

```java
@GetMapping("/api/v1/workout/{workoutId}/exercise/{exerciseId}")
public ResponseEntity<ApiResponse> handleListCompletedSetsForExercise(
        @PathVariable Integer workoutId, @PathVariable Integer exerciseId, @AuthenticationPrincipal User user) {
    var completedSets = workoutService.listCompletedSetsForExercise(user, exerciseId, workoutId);
    return ResponseEntity.ok(new ListCompletedSetsForExercise(completedSets));
}
```

This endpoint returns data in the following format:

```json5
{
    "completedSets": [
        {
            "id": 23,
            "weight": 100.5,
            "sets": 100,
            "reps": 1,
            // ... other fields ...
        },
        // .. rest
    ]
}
```


Now let's write a component to call this endpoint and display the completed sets, we'll call this component `<CompletedSets>`:

```jsx
type CompletedExercisesProps = {
    exercise: Exercise | null,
    workoutId: number | null
}

export default function CompletedSets({ exercise, workoutId }: CompletedExercisesProps) {
    const authStore = useAuthStore();
    const [completedSets, setCompletedSets] = useState<CompletedSet[]>([]);

    useEffect(() => {
        (async () => {
            const { completedSets } = await listCompletedSetsForExercise({
                sessionToken: authStore.sessionToken,
                workoutId: workoutId,
                exerciseId: exercise!.id
            });
            setCompletedSets(completedSets);
        })();
    }, [])

    return (
        <View>
            <Heading>Completed sets for {String(exercise?.name)}</Heading>
            <Text>There are {completedSets?.length} completed sets for this exercise</Text>
            <View>
                <View style={styles.tableHeader}>
                    <Text style={styles.tableHeaderCol}>Sets</Text>
                    <Text style={styles.tableHeaderCol}>Reps</Text>
                    <Text style={styles.tableHeaderCol}>Weight</Text>
                </View>
                <FlatList
                    style={{}}
                    data={completedSets}
                    renderItem={({ item: completedSet }) => (
                        <Pressable
                            style={styles.tableRow}
                            onPress={() => {}}>
                                <Text style={styles.tableCol}>{completedSet.sets}</Text>
                                <Text style={styles.tableCol}>{completedSet.reps}</Text>
                                <Text style={styles.tableCol}>{completedSet.weight}kg</Text>
                        </Pressable>
                    )}
                />
            </View>
        </View>
    )
}
```

It contains an extremely quick implementation of a table just to get the data displayed - we will improve it later on and add other features like sorting, column totals, and buttons to remove/edit sets.

And that's it for this screen, the final screen looks like this:

```jsx
export default function ExerciseSummaryScreen() {
    const workoutStore = useWorkoutStore();
    const router = useRouter();
    const params = useLocalSearchParams()

    useEffect(() => {
        router.setParams({
            title: workoutStore.currentExercise?.name
        });
    }, []);
    
    return (
        <ScreenLayout screenHasHeader={true}>
            <Stack.Screen 
                options={{
                    title: params.title
                }} 
            />
            <Box padding={20}>
                <Button title="Add set" href="/log-workout/add-exercise-to-workout" />
                
                <CompletedSets 
                    exercise={workoutStore.currentExercise} 
                    workoutId={workoutStore.workoutId}
                />
            </Box>
        </ScreenLayout>
    )
}
```

### Add exercise to workout screen

This screen contains a form the user fills in to add a set to an exercise. 

Let's write the form first:

```jsx
export default function AddExerciseToWorkoutScreen() {
    const { 
        control, 
        handleSubmit,
        formState: { errors },
        getValues
    } = useForm<AddExerciseForm>({
        mode: "all",
        defaultValues: {
            weight: 0,
            sets: 1,
            reps: 1,
            notes: '',
            equipment: ''
        }
    });

    return (
        <ScreenLayout screenHasHeader={true}>
            <Box padding={20}>
                {/* Weight */}
                <View style={formStyles.inputContainer}>
                    <Text style={formStyles.label}>Weight</Text>
                    <Controller 
                        control={control}
                        name="weight"
                        rules={{
                            min: {
                                value: 1,
                                message: 'Weight must be at least 1KG'
                            }
                        }} 
                        render={({ field: { onChange, value } }) => (
                            <TextInput 
                                value={String(value)}
                                onChangeText={onChange}
                                style={formStyles.input}
                            />
                        )}
                    />
                    <FieldErrorMessage fieldError={errors.weight} />
                </View>

                {/* Sets */}
                <View style={formStyles.inputContainer}>
                    <Text style={formStyles.label}>Sets</Text>
                    <Controller 
                        control={control}
                        name="sets"
                        rules={{}} 
                        render={({ field: { onChange, value } }) => (
                            <TextInput 
                                value={String(value)}
                                onChangeText={onChange}
                                style={formStyles.input}
                            />
                        )}
                    />
                    <FieldErrorMessage fieldError={errors.sets} />
                </View>

                {/* Reps */}
                <View style={formStyles.inputContainer}>
                    <Text style={formStyles.label}>Reps</Text>
                    <Controller 
                        control={control}
                        name="reps"
                        rules={{}} 
                        render={({ field: { onChange, value } }) => (
                            <TextInput 
                                value={String(value)}
                                onChangeText={onChange}
                                style={formStyles.input}
                            />
                        )}
                    />
                    <FieldErrorMessage fieldError={errors.reps} />
                </View>

                {/* Notes */}
                <View style={formStyles.inputContainer}>
                    <Text style={formStyles.label}>Notes</Text>
                    <Controller 
                        control={control}
                        name="notes"
                        rules={{}} 
                        render={({ field: { onChange, value } }) => (
                            <TextInput 
                                value={String(value)}
                                onChangeText={onChange}
                                style={formStyles.input}
                            />
                        )}
                    />
                    <FieldErrorMessage fieldError={errors.notes} />
                </View>

                {/* Equipment */}
                <View style={formStyles.inputContainer}>
                    <Text style={formStyles.label}>Equipment</Text>
                    <Controller 
                        control={control}
                        name="equipment"
                        rules={{}} 
                        render={({ field: { onChange, value } }) => (
                            <TextInput 
                                value={String(value)}
                                onChangeText={onChange}
                                style={formStyles.input}
                            />
                        )}
                    />
                    <FieldErrorMessage fieldError={errors.equipment} />
                </View>

                <Button 
                    title="Add"
                    onPress={handleSubmit(() => {})}
                />
            </Box>
        </ScreenLayout>
    )
}
```

Very simple stuff.

After submitting the form, we need to call our endpoint `/api/v1/workout/{workoutId}/exercise/` to add the exercise to the workout, then send to user back to the **exercise summary page**:

```jsx
async function handleAddSet() {
    console.log('Adding set', getValues());
    setIsLoading(true);

    const formValues = getValues();
    const { success } = await logExercise({
        workoutId: workoutStore.workoutId!,
        exerciseId: workoutStore.currentExercise?.id!,
        weight: formValues.weight,
        sets: formValues.sets,
        reps: formValues.reps,
        notes: formValues.notes,
        equipment: formValues.equipment.split(','),
        sessionToken: authStore.sessionToken
    });

    if(!success) {
        console.error('Failed to log workout');
        // todo: Handle server-side validation errors.
    } else {
        // No need to navigate anywhere, just pop the screen off the navigation stack.
        router.dismiss();
    }

    setIsLoading(false);
}
```

This is a very primitive implementation, it doesn't handle a number of things:
- Server-side validation response
- Failed requests
- Request cancelling

For now it will suffice - we'll improve it later on.

### Workout summary screen

This screen lists 

Our performed exercises live in the database in the `workout_exercise` table, we could just return those to the client, but then the client would have to do some manual grouping of those to display them, a better alternative would be to return a structure like this:

```json5
{
    "exercices": [
        {
            // This is the `Exercise` model data
            "id": 1,
            "name": "Back squat",
            "performed": [
                // This is the `WorkoutExercise` model data
                {
                    "id": 23,
                    "weight": 100.5,
                    "sets": 100,
                    "reps": 1
                }
            ]
        }
    ]
}
```

This requires more code on the server, but means the client can just loop over the `exercises` array. 

Let's write our service method to achieve this:

```java
public List<ExerciseWithCompletedSets> listExercisesForWorkoutId(@NotNull User user, @NotNull Integer workoutId) {
    var workout = workoutDao.findOneWithUser(workoutId);
    if (workout == null) {
        return Collections.emptyList();
    }

    if (!workout.getUser().equals(user)) {
        return Collections.emptyList();
    }

    // Fetch ALL the exercises for this workout
    var allWorkoutExercises = workoutExerciseDao.findAllByWorkoutId(workoutId);

    // Create a map of Exercise => WorkoutExercise so it's easier to work with
    Map<Exercise, List<WorkoutExercise>> exerciseToWorkoutExerciseMap = allWorkoutExercises.stream()
        .collect(Collectors.groupingBy(WorkoutExercise::getExercise));

    // Map it to our model
    return exerciseToWorkoutExerciseMap.entrySet().stream().map(entry -> {
        var exercise = entry.getKey();
        var workoutExercises = entry.getValue();

        var exerciseWithCompletedSets = new ExerciseWithCompletedSets();
        exerciseWithCompletedSets.setId(exercise.getId());
        exerciseWithCompletedSets.setName(exercise.getName());
        
        var completedSets = workoutExercises.stream()
            .map(this::mapFromWorkoutExercise)
            .toList();
        exerciseWithCompletedSets.setCompleted(completedSets);

        return exerciseWithCompletedSets;
    }).toList();
}
```

This is fairly simple, most of the complexity comes from mapping between our models `WorkoutExercise` and `Exercise` to our view models `ExerciseWithCompletedSets` and `CompletedSet`.

One feature which I had totally forgotten about was `Collectors#groupingBy` which makes creating a map from a list a breeze - initially I wrote this by manually constructing the map before asking [Gemini](https://gemini.google.com/) if there was a simpler way to write it.

### Confirmation modal

### Success screen

## Conclusion

We've now built a rough version of the main functionality in our app.

In the next part, we'll...

[Bye for now](https://www.youtube.com/watch?v=JgFvNzLAWtY)