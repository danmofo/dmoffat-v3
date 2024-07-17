---
layout: '@layouts/BlogLayout.astro'
title: 'Building a fitness tracking app with Java - Part four'
pubDate: 2024-07-16
description: 'How I built a fitness tracking app using Java, MySQL, React Native and more.'
draft: true
series_posts:
  - name: Part one
    path: /writing/2024/07/building-a-fitness-app-with-java-part-1
  - name: Part two
    path: /writing/2024/07/building-a-fitness-app-with-java-part-2
  - name: Part three
    path: /writing/2024/07/building-a-fitness-app-with-java-part-3
  - name: Part four
    path: /writing/2024/07/building-a-fitness-app-with-java-part-4
---

- [What we're going to work on](#what-were-going-to-work-on)
- [Creating a new React Native project](#creating-a-new-react-native-project)
- [Building the app](#building-the-app)
  - [Setting up](#setting-up)
  - [Homepage](#homepage)
  - [Log in screen](#log-in-screen)
    - [Form validation](#form-validation)
    - [Sending a request to our API](#sending-a-request-to-our-api)
  - [Dashboard](#dashboard)
- [Conclusion](#conclusion)

## What we're going to work on

As mentioned in [part three](/writing/2024/07/building-a-fitness-app-with-java-part-3), we're going to start building the mobile app using React Native.

I decided to use React Native as it's something I've recently (around a month and a half) been introduced to at work and I thought it would be a good way to develop those skills further. I found the developer experience for React Native really nice, and I can use tools/languages I'm already familiar with (JS/TS/CSS/etc.).

It's worth mentioning at this point - **I am by no means an expert in RN development**, everything you see in this post is the result of reading the documentation and trial and error 🙂 I'll be refactoring as I go along.

## Creating a new React Native project

When I was building our app at work, I wrote down the steps I used to initialise my project, so I can just repeat those again. 

To create a React Native app, you use something called [Expo](https://expo.dev/) (recommended by the React Native team). As far I've as understood, it's a framework with a lot of stuff built-in which you'd otherwise have to build/setup yourself (file-based routing and TypeScript integration as two examples), has a bunch of useful libraries (`expo-image`, `expo-font`, etc.) and probably lots more things that I'll discover as I go along.

I initially tried creating a RN app without Expo when exploring the technology, and the difference in experience between bare RN and Expo was huge.

First let's create the app:

```bash
npx create-expo-app@latest <app_name> --template https://github.com/expo/expo-template-default
```

Then run the `expo prebuild` command:

```bash
npx expo prebuild --template https://github.com/expo/expo/tree/main/templates/expo-template-bare-minimum
```

This generates the directories (`ios`/`android`) where the native code lives. 

Normally you wouldn't run this manually, you'd just run `npx expo run android`, which would execute `expo prebuild` as part of its initialisation process, however that didn't work for me, so I had to run it manually.

To run it, you'll either need an emulator created through Android Studio, or a physical device connected via USB/WiFi. I connect through WiFi by enabling wireless debugging on my Android phone (Pixel 5) and connecting with the following (the port can be found under "Wireless Debugging"):

```bash
adb connect 192.168.0.6:random_generated_port
```

Then you can start the app like so:

```
npx expo run android
```

This will take a while, but eventually you'll need greeted with the Expo example app on your phone:

![Expo example app homescreen](../../../../assets/images/fitness-app-article/expo-example-app.jpg)

## Building the app

Before we write any code, we'll install `expo-dev-client` to [add a developer menu](https://docs.expo.dev/versions/latest/sdk/dev-client/):

```bash
npx expo install expo-dev-client
```

At this point we have an application flow, and the backend APIs each screen will call, but we have no visual design for the app yet. As I go along I'm going to create a wireframe for each screen using a pen and paper.

I debated creating mockups, but don't feel like learning any design tools at the moment - in the past I've used Sketch/Adobe Illustrator. The former is Mac only, and the latter carries a subscription fee.

### Setting up

First we need to get rid of the example code added by Expo, we can do that by running:

```bash
# Move all of the example code into 'app-example'
npm run reset-project

# Remove 'app-example'
rm -rf ./app-example/ 
```

Now we can start writing code.

### Homepage

The "homepage" of our app will serve do a few things:
- If the user is not logged in, show them a welcome screen, with buttons to log in/sign up
- If the user is logged in, send them to their dashboard to start logging things

Let's write a screen:

```jsx
import Box from "@/components/layout/Box";
import ScreenLayout from "@/components/layout/ScreenLayout";
import Heading from "@/components/text/Heading";
import { router } from "expo-router";
import { Button, Text } from "react-native";

export default function HomepageScreen() {
    return (
        <ScreenLayout screenHasHeader={false}>
            <Box padding={20}>
                <Heading>Welcome to Fitness Tracker App!</Heading>
                <Text>This section will describe in a few words what you can do on this app.</Text>
                <Text>To get started, either log in or sign up:</Text>
            </Box>
            <Box flex={1} padding={20} clampChildrenToBottom>
                <Button title="Log in" onPress={() => router.navigate("/auth/log-in")} />
                <Button title="Sign up" onPress={() => router.navigate("/auth/sign-up")} />
            </Box>
        </ScreenLayout>
    );
}
```

This is very simple, we did a few things:
- Created a `<ScreenLayout>` component which will wrap every screen in our app. I did this so I could set the background colour consistently and also depending on the context, wrap the screen in either a `<View>` or a `<SafeAreaView>` (when used with a navigation stack).
- Created a `<Box>` component which we use for laying out different sections on the page, rather than wrapping everything in individual `<View>` components. The props are things which you commonly set for layout - `padding`, `margin`, `flex`, etc.
- Created a `<Heading>` component which we will use for headings. In the future if we decide to add themes, we can change the font styles/colours in here.

We use native buttons for now with inline event handlers, later on we'll create our own `<Button>` component which is wrapped in `expo-router`s `<Link>` component.

### Log in screen

The log in screen's sole purpose is to authenticate the current user and obtain a session token for use later on. This screen is interesting as we'll need to implement a few things:
- Form validation
- Sending a request to our API
- Storing our session token in some global state

#### Form validation

Whilst we could write our forms and validation from scratch, I'm going to make use of [React Hook Form](https://react-hook-form.com/) instead. I'm familiar with how it works and it will allow us to keep moving quickly.

Let's install it:

```bash
npm install --save react-hook-form
```

Then let's write an empty `LoginForm` component:

```jsx
import { Text } from "react-native";

export default function LogInForm() {
    return (
        <Text>Form goes here</Text>
    )
}
```

To implement a form we'll first need to create our form type:

```ts
type LoginForm {
    email: string
    password: string
}
```

Then we'll need to call React Hook Form's `useForm` hook ([as described in their docs](https://react-hook-form.com/get-started#ReactNative)):

```ts
const { 
    control, 
    handleSubmit,
    formState
} = useForm<LoginForm>({
    mode: "all",
    defaultValues: {
        email: '',
        password: ''
    }
});
```

There's 3 properties we're interested in: `control` (needed for `<Controller>`), `handleSubmit` (which we'll call from our button) and `formState`, which as the name implies will allow us to get hold of any errors and whether the form is valid or not.

Then we create our input like so:

```jsx
<View>
    <Text style={{}}>Email address</Text>
    <Controller 
        control={control}
        name="email"
        rules={{
            required: 'Please enter an email address'
        }} 
        render={({ field: { onChange, value } }) => (
            <TextInput 
                value={value}
                onChangeText={onChange}
                style={{}}
            />
        )}
    />
    {errors.email ? <Text style={{}}>{errors.email.message}</Text> : null}
</View>
```

Next we need to add some styling. My first thought was to create components for each aspect of the form (label, input, errors), but I think a simpler approach for now is to create some global styles (in `styles.ts`) and use them in the `style` attribute of our components. We can always create components later on when we've got a better idea how they will be used in our app.

We create some global styles like this:

```ts
export const formStyles = StyleSheet.create({
    label: {
        marginBottom: 8
    },
    input: {
        borderWidth: 1,
        borderColor: '#CCC'
    }
});
```

And use them like this:

```jsx
<Text style={formStyles.label}>My form label</Text>
```

I'm not sure if styling this way is the preferred approach (I didn't do any research yet), the only other method I could think of is wrapping your components in other components whose sole responsibility is to style them (e.g. `<Heading>`, `<Label>`).

Finally we write our submit button:

```jsx
<Button title="Log in" onPress={handleSubmit(handlePressLogInButton)}/>
```

This calls React Hook Form's `handleSubmit` function when pressed which will trigger form validation. If the form is valid, then it calls our function `handlePressLogInButton`, which is where we'll add the logic to actually log in.

The only thing that's left to do is add email validation to the email address field:

```jsx
<Controller 
    // ...
    rules={{
        required: 'Please enter an email address',
        pattern: {
            // <something>@<something>.<tld>
            value: /.+@.+\..+/,
            message: 'Please enter a valid email address'
        }
    }} 
    // ...
/>
```

That's validation done - next we need to send the request to our API.

#### Sending a request to our API

### Dashboard

Some text.

## Conclusion

In the next part we'll

[Bye for now](https://www.youtube.com/watch?v=JgFvNzLAWtY)