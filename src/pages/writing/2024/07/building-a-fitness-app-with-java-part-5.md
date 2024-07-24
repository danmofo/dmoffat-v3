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

We've already built the APIs that power these screens, so most of the coding we'll do will be building the screens and talking to our APIs.

### Layout

First we'll create a separate layout for the log workout process so that we have a header (so far the app hasn't used any headers). The header contains useful things such as a title, and a back button. This is as simple as creating a `_layout.tsx` file in our `log-workout` folder with the following contents:

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
    if(!workoutId) {
        Alert.alert("Failed to start workout, please try again.");
        return;
    }

    router.navigate("/log-workout/select-exercise");
}
```

Now we have a workout ID, we need to persist it somewhere. I thought of two places I could store this:
- In a global store
- In a path variable, e.g. `/log-workout/{workoutId}/select-exercise`

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

Unlike `expo-secure-store` we don't need to write our own adapter to persist our store, because `AsyncStorage` satisfies `StateStorage`s interface.

Then update our event handler to store the workout ID in the store:

```ts
async function handleStartWorkout() {
    const { workoutId } = await startWorkout({ sessionToken });
    if(workoutId === null) {
        Alert.alert("Failed to start workout, please try again.");
        return;
    }

    workoutStore.startWorkout(workoutId!);

    router.navigate("/log-workout/select-exercise");
}
```

The final thing, which I noticed whilst developing this screen is that when going through the "Start workout" flow, we'll end up with a bunch of workout IDs for abandoned workouts. To get around this, when you click "START", we'll check for any workouts that are in progress.

```ts
if(workoutStore.hasWorkoutInProgress()) {
    console.log('Workout already started.');
    router.navigate('/log-workout/select-exercise');
    return;
}
```

In the future, we'll implement some sort of "Resume workout" functionality.

That's it for this screen, we now have the `workoutId` available throughout the process, which we'll need later on to log individual exercises.

### Select exercise screen

This is where the user selects the exercise they want to perform. When the screen loads it will show a list of all exercies, and typing in the search box will filter down the search results. Because the list of exercises is small, I think we can get away with loading a list of ALL exercises, and just performing the filtering in memory with a primitive text search.

> **Side note** In the future, we'll improve this by performing the search operations on the server, this will be especially useful as the number of exercises increases.

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

This component doesn't really do much, just propagates the `TextInput`s event to the parent component.

And an `ExerciseList` for displaying the exercises:

```jsx
type ExerciseListProps = {
    exercises: Exercise[],
    onSelectExercise: (exercise: Exercise) => void
}

export default function ExerciseList({ exercises, onSelectExercise }: ExerciseListProps) {
    if(!exercises) {
        return <Text>Loading exercises...</Text>
    }

    if(exercises?.length === 0) {
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

So now we have a list of exercises displayed, but the search box isn't filtering them, let's filter the list of exercises before it's passed a prop to `ExerciseList`. We could do this inside the `handleChangeQuery` event handler (which is invoked when the search box's text changes) we have:

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

### Exercise summary screen

This screen displays a summary of all completed sets for the current exercise, and the user can add their performed exercises to a workout.

We want the screen's header to be dynamic (display the currently selected exercise's name), which requires us to move the `<Stack.Screen>` component into the route file, so we remove it from `_layout.tsx` and add it to our `workout-add-exercise.tsx` route:

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

To display the list of completed sets, we'll need to ask the server for completed sets with a specific `exercise_id` and a specific `workout_id`. We actually didn't build that endpoint, so first let's go ahead and write that:

```java
@GetMapping("/api/v1/workout/{workoutId}/exercise")
public ResponseEntity<ApiResponse> handleListWorkoutExercises(
    @PathVariable Integer workoutId, @AuthenticationPrincipal User user) {

    var exercises = workoutService.listExercisesForWorkoutId(user, workoutId);
    
    return ResponseEntity.ok(new ListWorkoutExerciseResponse(exercises));
}
```

Our performed exercises live in the database in the `workout_exercise` table, we could just return those to the client, but then the client would have to do some manual grouping of those so they could display them, a better alternative would be to return a structure like this:

```json
{
    "exercices": [
        {
            "id": 1,
            "name": "Back squat",
            "performed": [
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

This requires more code on the server, but means the client doesn't need to do anything except loop over the `exercises` array.

### Add exercise to workout screen

This screen contains a form the user fills in to add a set to an exercise. 

The code looks something like this:

```jsx
// todo
```

After submitting the form, we need to do two things:
1. Call our endpoint `/api/v1/blah` to add the exercise to the workout
2. Save this exercise in some persistent storage, so that we can display it on the **exercise summary** screen.

### Workout summary screen

### Confirmation modal

### Success screen

## Conclusion

We've now built a rough version of the main functionality in our app.

In the next part, we'll...

[Bye for now](https://www.youtube.com/watch?v=JgFvNzLAWtY)