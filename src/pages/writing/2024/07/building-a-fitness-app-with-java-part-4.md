---
layout: '@layouts/BlogLayout.astro'
title: 'Building a fitness tracking app with Java - Part four'
pubDate: 2024-07-16
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
---

- [What we're going to work on](#what-were-going-to-work-on)
- [Creating a new React Native project](#creating-a-new-react-native-project)
- [Building the app](#building-the-app)
  - [Header one](#header-one)
  - [Header two](#header-two)
- [Conclusion](#conclusion)

## What we're going to work on

As mentioned in [part three](/writing/2024/07/building-a-fitness-app-with-java-part-3), we're going to start building the mobile app using React Native.

I decided to use React Native as it's something I've recently (around a month and a half) been introduced to at work and I thought it would be a good way to develop those skills further. I found the developer experience for React Native really nice, and I can use tools/languages I'm already familiar with (JS/TS/CSS/etc.).

It's worth mentioning at this point - **I am by no means an expert in RN development**, everything you see in this post is the result of reading the documentation and trial and error 🙂

## Creating a new React Native project

When I was building our app at work, I wrote down the steps I used to initialise my project, so I can simply repeat those again. 

To create a React Native app, you use something called [Expo](https://expo.dev/) (recommended by the React Native team). As far I've as understood, it's a framework with a lot of stuff built-in which you'd otherwise have to build/setup yourself (file-based routing and TypeScript integration as two examples), has a bunch of useful libraries (`expo-image`, `expo-font`, etc.) and lots more things that I'll discover as I go along.

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

### Header one

Some text.

### Header two

Some text.

## Conclusion

In the next part we'll

[Bye for now](https://www.youtube.com/watch?v=JgFvNzLAWtY)