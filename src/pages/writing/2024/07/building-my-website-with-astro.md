---
layout: '@layouts/BlogLayout.astro'
title: 'Building my website with Astro'
pubDate: 2024-07-02 19:43
description: 'Walking through how I rebuilt my website, from design all the way through to deployment.'
---

- [Introduction](#introduction)
- [My approach to building things](#my-approach-to-building-things)
- [Setting up](#setting-up)
- [Building the homepage](#building-the-homepage)
- [Adding a blog section](#adding-a-blog-section)
- [Listing the blog posts on the homepage](#listing-the-blog-posts-on-the-homepage)
- [Date formatting](#date-formatting)
- [Cleaning up import paths](#cleaning-up-import-paths)
- [Making it look nice](#making-it-look-nice)
- [Writing CSS](#writing-css)
  - [Organisation](#organisation)
  - [Class names](#class-names)
  - [Flexbox](#flexbox)
  - [CSS variables](#css-variables)
  - [CSS units](#css-units)
- [Writing HTML](#writing-html)
  - [Responsive images](#responsive-images)
- [Accessibility](#accessibility)
- [Optimisation and Performance](#optimisation-and-performance)
  - [Images](#images)
- [Deploying](#deploying)
  - [Generating an SSL certificate using Letsencrypt](#generating-an-ssl-certificate-using-letsencrypt)
  - [Creating the Letsencrypt Docker container](#creating-the-letsencrypt-docker-container)
  - [Running certbot](#running-certbot)
  - [Testing it all out](#testing-it-all-out)
  - [Automating Docker commands](#automating-docker-commands)
  - [Updating nginx to use SSL](#updating-nginx-to-use-ssl)
  - [Pushing our container to DigitalOcean's container repository](#pushing-our-container-to-digitaloceans-container-repository)
  - [Pulling the docker container on our server and running it](#pulling-the-docker-container-on-our-server-and-running-it)
  - [Cleaning up](#cleaning-up)
- [Fin](#fin)

## Introduction

It's been a long time since I've had a personal website online. The latest iteration was a single HTML page that I threw together in an afternoon, with hopes of improving it, followed by swiftly forgetting about it a week later.

I wanted to build it using something modern, using technology I already know (HTML/CSS/JS) and with a good developer experience (no manual configuration of build systems).

A few weeks prior I stumbled upon Astro, which seemed like a good choice for the following reasons:
- It generates a static website consisting of plain HTML/JS/CSS, which can be hosted using a regular web server (nginx, for example)
- You get some of the niceties of server-rendered pages (dynamic content, includes, variables, etc.) without having to host a fully blown Node or *insert programming language* program.
- The documentation looked straightforward
- The homepage looked nice 😂 - whilst this is a terrible reason to pick a framework, it really does make a difference.

I'll now try to describe (roughly) how I built it, with some pointless history about myself sprinkled in.

## My approach to building things

When building anything, whether for work, or a side project, my process is as follows:
- Create a markdown file and write down the high-level task I'm trying to do
- Break it down into things I need to build
- Build a rough initial version
- Iterate on this version until I'm happy with the final result

As I go along I'll write down things that come into my mind (e.g. edge cases I stumble across, how should I handle XYZ, bugs, etc)

## Setting up

Setting up the website structure was straightforward, you run a command to scaffold the project (following the prompts from the CLI):

```bash
npm create astro@latest
```

And another command to start the dev server:

```bash
npm run dev
```

The CLI asks you if you want some examples added to the generated project, which for me, was more than enough to learn about how everything fits together without needing to read the docs just yet.

## Building the homepage

First I created a layout (`BaseLayout.astro`) that would be used for the website, this consisted of the "header" (the bit on the left) and the content section (the bit on the right).

I defined some properties for the layout (`title`  and `description`) so that each page could define their own title/description to go in the `<head>`:


```astro
---
interface Props {
    title: string,
    description: string
}

const { title, description } = Astro.props;
---

<!doctype html>
<html lang="en">
    <head>
        <!-- Other HTML is here -->
        <title>{title}</title>
        <meta name="description" content={description} />
    </head>
    <body>
        <main>
            <header>
                <!-- Header goes here -->
            </header>
            <div class="content">
                <slot />
            </div>
        </main>
    </body>
</html>

```

And this layout gets used like so:

```astro
<BaseLayout title="My title" description="my-description">
    <p>The content for this page goes here.</p>
</BaseLayout>
```

This is very similar to other templating languages in server-rendered websites (i.e. Freemarker for Java) and allows us to avoid repeating the website structure on each page (like you'd have to if you wrote it using only HTML). Unlike server-rendered websites however, this logic is evaluated at build time.

## Adding a blog section

Next I wanted to add a section where I could add blog posts, ideally in markdown format. Astro has built in support for this functionality, you can write plain `.md` files and they get automatically converted to HTML at build time. You don't need to enable anything, just drop your files in the `src/pages` directory.

So now we've got some blog post HTML, but I wasn't sure how to wrap that in a layout. After reading the docs, I saw you could add a `layout` property to your markdown page's metadata (aka "frontmatter"), like so:

```markdown
---
layout: path/to/layouts/BlogLayout.astro
title: 'Post title'
pubDate: 2024-07-02
---
```

Now our markdown HTML is wrapped in a layout, however `BlogLayout.astro` is basically `BaseLayout.astro` duplicated, I needed to find a way to re-use `BaseLayout.astro`.

In the docs, I stumbled upon a section on [nesting layouts](https://docs.astro.build/en/basics/layouts/#nesting-layouts) which let me accomplish what I wanted, our `BlogLayout.astro` now looks something like this:

```astro
---
import BaseLayout from './BaseLayout.astro';

const { frontmatter } = Astro.props;
---

<BaseLayout title={frontmatter.title} description={frontmatter.description}>
    <h1>{frontmatter.title}</h1>
    <p>Published on: {frontmatter.pubDate}</p>
    <slot />
</BaseLayout>
```

This has the added benefit of allowing us to set the page's title/description to values from the markdown file itself.

The end result is the blog section appearing in the main content area of the website and no duplicated page structure HTML.

## Listing the blog posts on the homepage

This was surprisingly easy, I created a component named `<BlogPosts>` and used `Astro.glob` to get a list of all `md` files in a specific directory, it looks something like this:

```astro
---
const posts = await Astro.glob('../pages/writing/*/*/*.md');
---

<p>Here are my latest posts:</p>
<ul>
    {
        posts.map(post => {
            return (
                <li>
                    <a href={post.url}>{post.frontmatter.title}</a> - {post.frontmatter.pubDate}
                </li>
            )
        })
    }
</ul>
```

Nice and simple.

## Date formatting

When displayed on the page, our `pubDate` appears like this: `2024-07-02T00:00:00.000Z`. This isn't very readable, so I wrote a component to format it:

```astro
---
type Props = {
    date: string
}

const formattedDate = new Date(Astro.props.date).toLocaleDateString('en-GB');
---

<span class="date">{formattedDate}</span>
```

Which can be used in a template like so:

```astro
<PrettyDate date={someVariableContainingADateString} />
```

There's no reason this couldn't have just been a regular function (e.g. `formatDate()`), I just wanted to write a component instead.

## Cleaning up import paths

Astro import paths are relative, so in our blog content, we end up with ugly references to layouts (and other imports) like so: 

```astro
---
layout: ../../../../layouts/BlogLayout.astro
---
```

This is brittle, we can't move the posts to another folder without having to update the imports, we can use [imports](https://docs.astro.build/en/guides/imports/#aliases) to fix this.


Inside `tsconfig.json`:

```json
{
  "extends": "astro/tsconfigs/strict",
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@public/*": ["public/*"],
      "@components/*": ["src/components/*"],
      "@layouts/*": ["src/layouts/*"]
    }
  }
}
```

Now in our blog post:
```astro
---
layout: '@layouts/BlogLayout.astro'
---
```

This also plays nicely with VSCode, and following references (pressing F12) still works.

## Making it look nice

Now that we've got most of the content and structure out of the way, it's time to make it look nice.

In the past I'd:
- Create the design for mobile and desktop using [Sketch](https://www.sketch.com/)
- Build it in the browser

Since I no longer have a Mac (I use Ubuntu) and have no desire to learn any more Linux/web-based design software, I decided to create the design directly in the browser, which basically means writing the HTML, then tweaking the CSS until you're happy with the result.

## Writing CSS

In the past when I mainly did frontend developement I would write CSS (LESS/SASS) daily, nowadays the only CSS I write is for our browser extension, which is quite different from website CSS.

Browser extension CSS is generally more rigid, browser UI elements have a fixed size (so you don't need to worry about devices with differing dimensions) and the UI generally has fewer elements/states. Overall CSS architecture is not that important as you're only writing a few hundred lines of CSS.

Because of this I haven't really had to keep up with the latest developments in CSS (outside of things I needed to work on), so I thought now would be a good time to expose myself to those things.

As always, I'll write the CSS using a mobile-first approach. I've decided against using a CSS preprocessor, it's overkill for a website that consists of at most 2 separate pages, and detracts from what I'm trying to do.

> **Side note:** I've become much better at not adding technology unnecessarily to projects as I get older. Younger me would have happily reached for SASS as a default when writing CSS.

### Organisation

When writing CSS I generally stick to the following structure in my CSS files:

```css
/* Base styles / resets */

/* Page layout */

/* Typography */

/* Components, e.g. buttons, inputs */

/* Individual page styles */

/* Utility classes */
```

I write the mobile CSS first, then use media queries to change things as the screen size gets larger. This is much nicer when using a CSS preprocessor as you can use a mixin to reduce boilerplate:

```scss
.my-component {
    background-color: red;

    @include media('medium') {
        background-color: blue;
    }
}
```

It's still not that bad in regular CSS though:

```css
.my-component {
    background-color: red;
}

@media(min-width: 999px) {
    .my-component {
        background-color: blue;
    }
}
```

### Class names

I've noticed a lot of CSS frameworks now use a utility class approach (Tailwind, Bootstrap):

```html
<div class="p-20 mt-10 mb-10 p:xs-10">
    <h1 class="mt-0 mb-20 text-xl color-brand">Some title</h1>
    <p class="fs-18 fs:xs-30 text-sm">Lorem ipsum dolor sit amet, consectetur adipisicing elit. Modi voluptates quaerat inventore, ut necessitatibus consectetur nemo optio quo, repellat quae totam delectus magnam, quasi quas esse asperiores molestias iure dolorem!</p>
</div>
```

This has the advantages of:
- Controlling the styling purely by changing classes and not writing more CSS - if I want to change the padding, I can change `p-20` to `p-15` for example.
- If you've got the classes in place, you can quickly prototype/build new layouts without writing CSS

Rather than a component-based approach (with [BEM naming conventions](https://getbem.com/)):

```html
<div class="block">
    <h1 class="block__title">Some title</h1>
    <p class="block__text">Lorem ipsum dolor sit amet, consectetur adipisicing elit. Modi voluptates quaerat inventore, ut necessitatibus consectetur nemo optio quo, repellat quae totam delectus magnam, quasi quas esse asperiores molestias iure dolorem!</p>
</div>
```

This has the advantages of:
- Making the HTML easier to read
- "Separation of concerns", not putting styling information in the HTML - this is something I don't really mind
- Making it easier to find code, the code for a block would live in `components/block`

> **Side note:** Using a CSS preprocessor, you can combine both approaches, having "nice" class names powered by extends/includes:
>
> ```scss
> .block {
>     @include text-sm();
>     @include padding(20, 20);
>     // ...
> }
> ```


I prefer the component-based approach with some utility classes (for things like grids), purely due to what I'm comfortable with. For this website, it won't make a great deal of difference as the overall number of pages and styles are low - I could get away with styling the elements directly.

### Flexbox

In the past for website layouts I've used float-based grids (which I realise makes me sound really old) such as [Bootstrap](https://getbootstrap.com/) and [Susy](https://www.oddbird.net/susy/) as flexbox wasn't supported on the browsers I was developing for at the time (pre-Chromium Microsoft Edge and Internet Explorer, amongst others).

I use flexbox for layout in our browser extension, and in our mobile app (React Native), but haven't used it to build responsive website layouts, so I decided to use that for the overall layout.

Implementing this was fairly simple, on mobile, everything stacks on top of each other and on larger devices the layout changes to two columns. 

We also get some added benefits, like being able to change the order the HTML elements appear in on different devices - I use this to make my name appear above the image on mobile devices, but below it on larger devices.

### CSS variables

I've always used preprocessors for variables in my CSS, for example:

```scss
$link-colour: blue;

a { 
    color: $link-colour;
}
```

This can now be done directly in CSS:

```css
:root {
    --link-colour: blue
}

a {
    var(--link-colour);
}
```

One slightly annoying thing I found out, is that you can't use it for media queries:

```css
:root {
    --breakpoint-sm: 640px;
}

/* Doesn't work */
@media (min-width: var(--breakpoint-sm)) {
    
}

```

I found [this blog post](https://bholmes.dev/blog/alternative-to-css-variable-media-queries/) which describes why.

### CSS units

In the past I've used `px` (occasionally `%`) for layout (padding, margin, width and height) and `px`/`rem` for font size, things like `vh`/`vw`/`ch` simply did not exist, or were not supported.

Trying to research this topic in 2024 brings up a variety of different answers, which I still didn't fully understand. For example, one article mentioned that using `rem` for font size is best, so that your font size scales with the browser's zoom. 

When I tested this myself with zooming (using CTRL + scroll wheel), it worked just fine, which confused me. After some digging I found [this article](https://www.joshwcomeau.com/css/surprising-truth-about-pixels-and-accessibility/) which explains it - setting font sizes in pixels completely ignores the user's font size setting in their browser (found in chrome://settings).

So if you have CSS like this:

```css
html {
    font-size: 16px;
}

p {
    font-size: 14px;
}

```

You will ignore the user's browser settings.

For this website I initially began using `px` for font sizing, but changed over to `rem` after finding out why.

[The article I mentioned previously](https://www.joshwcomeau.com/css/surprising-truth-about-pixels-and-accessibility/) has some other advice regarding which unit to use and the answer is: **it depends**. So I'm going to use `px`/`rem`, depending on the situation, rather than using one unit for everything.

## Writing HTML

As with CSS, I'd like to use "new" HTML stuff when building this website, as there are a lot more things that are part of the HTML standard which don't require JS.

### Responsive images

The first thing I looked at was responsive images. When I used to be a frontend developer, the latest and greatest technique for responsive images was using a JS library (can't remember the name of it) which would swap an `<img>` tag's `src` when the browser dimensions changed. 

Nowadays this is built directly into the browser, either through the an `<img>` tag with `sizes` and `srcset` attributes, or using the `<picture>` element.

I followed [this guide on MDN](https://developer.mozilla.org/en-US/docs/Learn/HTML/Multimedia_and_embedding/Responsive_images) for how to implement responsive images.

The header on the homepage contains a picture of me, on smaller devices I'd like this to display as a landscape picture (so you can see the scenery) but on the desktop I'd like it to appear as a smaller circle that doesn't take up as much space. I can achieve this using the `<picture>` element:

```html
<picture>
    <source media="(min-width: 768px)" srcset="/images/moi-circle.png" />
    <!-- Default image -->
    <img src="/images/moi-landscape.png" alt="..." />
</picture>
```

This could be optimised further (and will be later on) by:
- Adding a wider range of images for differing screen sizes, `moi-landscape.png` for example is currently 700px wide - which is way too large for a mobile device.
- Adding images for devices with different display densities (e.g. `2x`, `3x`)

## Accessibility

Despite working on a website for charities, I've got surprisingly little knowledge about making things accessible! I'm going to come back to this at a later date, after I've got the site deployed.

## Optimisation and Performance

To test the performance of my website, I needed to build the production-ready version. This is very easy using Astro (gone are the days of configuring Grunt/Gulp/Webpack/whatever build tool):

```bash
npm run astro build
```

The result is a `dist` folder with your website inside. I then hosted it locally using Python 3's builtin web server:

```bash
python3 -m 'http.server' 4231
```

Now that's done we can test it locally.

I wasn't really sure what the latest and greatest tools are nowadays with regards to frontend performance testing, in the past I've used [WebPageTest](https://www.webpagetest.org/) and PageSpeed Insights.

After some reading I found the following tools I could run locally:
- Lighthouse (built into Chrome devtools)
- [Web Vitals](https://chromewebstore.google.com/detail/web-vitals/ahfhijdlegdabablpippeagghigmibma)

I ran the Lighthouse performance test for mobile, which came up with the following things to fix:
- **Image size**, this makes sense as the images I've used are unoptimised both in size and compression.
- **Enabling text compression**, I ran the test using Python's builtin web server, which doesn't have GZIP compression enabled, so this is something that I can fix when deploying on a real web server.
- **No caching on static assets**, see previous point
- **Image elements without explicit height/width**, this was something new to me, I thought that you shouldn't hardcode dimensions on an image, but doing so stops the layout shifting around as the page loads.

### Images

I initially started going down the path of manually resizing images and running local image optimisation tools, but found out Astro has [built-in image optimisation](https://docs.astro.build/en/guides/images/) if you import images in a certain way.

First I had to move images from `public/images` to `src/images`, because by default, Astro just copies files from the `public` folder as-is.

Then I had to import them in my `.astro` file:

```astro
---
import moiLandscape from '@assets/images/moi-landscape.png';
---
```

This is where I got stuck. If I was just using the same image for mobile/desktop, using the `<Image>`/`<Picture>` components would have worked, but I couldn't figure out how to get it to generate `<source>` elements with different `media`/`srcset` attributes.

At this point I really just wanted to get something deployed rather than spend much more time looking into this. After reading more of the documentation I found out that Astro provides the image optimisation tools through a function named `getImage` if you cannot use their built-in components, I used it like so:

```astro
---
// Import the original image
import moiLandscape from '@assets/images/moi-landscape.png';

// Optimise it
const optimisedMoiLandscape = await getImage({
    src: moiLandscape,
    // Set the format
    format: 'avif',
    // ..the compression
    quality: 50,
    // ...and the width we'd like
    width: 750
});
---
<!-- Reference it in the template -->
<picture>
    <source 
        media="(min-width: 768px)" 
        srcset={optimisedMoiCircle.src}
        width="200"
        height="200"
    />
    <!-- Default image -->
    <img 
        src={optimisedMoiLandscape.src} 
        width={optimisedMoiLandscape.attributes.width}
        alt="A picture of me" 
        class="sidebar__photo"
    />
</picture>
```

We get an optimised image without needing to manually crop, resize and compress it, and as a bonus, it uses the `avif` format for smaller image sizes.

> **Side note:** I know this isn't the correct way to do this.

This isn't a perfect solution (it feels like we're working against Astro), but will do for now.

## Deploying

The simplest way to get this deployed would be installing nginx on my VPS, then copying the files into the directory where the website is served from. Although that works, I'd like to do it a different way.

When I host websites I always deploy them as Docker containers, Astro [has a guide](https://docs.astro.build/en/recipes/docker/) on how to build a Docker container with a built Astro website inside.

So now I've got a Docker container running with nginx inside, I need to actually deploy it to my VPS.

I've never actually created a proper deployment pipeline for my personal website, so I'm going to need to create this from scratch...

We'll need to do the following:
- Generate an SSL certificate using Letsencrypt (with DNS validation) and the DigitalOcean API
- Update our nginx config to listen on port 443 instead of port 80 and use the certificates we generated in the previous step
- Rebuild our nginx container with both the static website + the SSL cert inside
- Push the Docker container to DigitalOcean's container registry
- Pull the Docker container on our server and run it

Following my usual approach, I'll do it all manually, then write scripts to automate it.

### Generating an SSL certificate using Letsencrypt

I've used Letsencrypt for SSL certificates before (and we use them at work for local certs), and have written a script for another project which performs the cert generation + DNS validation steps, but I have no idea if it still works, so let's dig it out..

The script looks like this: 

```bash
# Generate the certificate
certbot certonly \
    --manual \
    --non-interactive \
    --agree-tos \
    --no-eff \
    --manual-public-ip-logging-ok \
    --manual-auth-hook /scripts/create-txt-record.sh \
    --manual-cleanup-hook /scripts/delete-txt-record.sh \
    --preferred-challenges dns \
    --email danmofo@gmail.com \
    --domain *.moff.rocks

echo "Certificates now being copied to conf/certs/moff.rocks"

# Copy the certificates to another folder
mkdir -p /certs/moff.rocks
cp -RL /etc/letsencrypt/live/moff.rocks/* /certs/moff.rocks/
chmod a=r /certs/moff.rocks/privkey.pem
```

A few things to note here:
- The domain is for another domain I own (moff.rocks), not the one I want to use (dmoffat.com)
- `/scripts/create-txt-record.sh` and `/scripts/delete-txt-record.sh` create `TXT` records for the given domain. Letsencrypt verifies that you own the domain by making you create `TXT` records with specific values
- It looks like this script is meant to be run inside a Docker container (based on the paths)

So to get these scripts working we have to do a few things:
- Generate a DigitalOcean API key
- Create a Letsencrypt Docker container which has `certbot` available
- Copy the scripts into said container
- Run the script above 

The end result will be a bunch of files we can use in our nginx container to serve the website over HTTPS.

> **Side note:** There's probably some software/script online that automates this process, I just haven't looked into it.

### Creating the Letsencrypt Docker container

This is straightforward, create a `Dockerfile` and copy our scripts created in the previous step:

```docker
FROM alpine:3.20.1

RUN apk add certbot curl jq bash

# Copy our API key
COPY .env /.env

# Copy scripts to create/delete TXT records
COPY scripts/create-txt-record /scripts/
COPY scripts/delete-txt-record /scripts/
```

And build it (we can write scripts to make this easier later):

```bash
docker build --file dockerfiles/letsencrypt.dockerfile -t 'dmoffat-letsencrypt' .
```

We can run it and make sure our files are there and software is installed:

```bash
docker run --rm -it dmoffat-letsencrypt
```

Looks good. Next we need to write a script that actually calls the `certbot` executable to generate the certicate, then add it to this Dockerfile.

### Running certbot

I copied this from an old script, but it's pretty self-explanatory:

```bash
certbot certonly \
    # Run in manual mode
    --manual \
    --non-interactive \
    # Automatically agree to prompt(s)
    --agree-tos \
    --no-eff \
    --manual-public-ip-logging-ok \
    # Run scripts before and after
    --manual-auth-hook /scripts/create-txt-record.sh \
    --manual-cleanup-hook /scripts/delete-txt-record.sh \
    # Use DNS verification
    --preferred-challenges dns \
    # My email
    --email danmofo@gmail.com \
    # The domain
    --domain *.dmoffat.com
```

I put this into a script named `generate-certs`, and will add it to my Dockerfile.


### Testing it all out

So now we've got everything in place to generate our certificates, we need to make sure the certificates actually get generated (before doing something with them later on!)

```
7f374eea6c18:/scripts# ./generate-certs 

Use of --manual-public-ip-logging-ok is deprecated.
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Account registered.
Requesting a certificate for *.dmoffat.com
Hook '--manual-auth-hook' for dmoffat.com ran with output:
 Creating TXT record for dmoffat.com
 Using value: l0sz1eDGmVmx_qswuUkX-YDcAm6LJ7vZBGp7sY-kUDQ
 {"domain_record":{"id":1744875958,"type":"TXT","name":"_acme-challenge","data":"l0sz1eDGmVmx_qswuUkX-YDcAm6LJ7vZBGp7sY-kUDQ","priority":null,"port":null,"ttl":30,"weight":null,"flags":null,"tag":null}}
Hook '--manual-cleanup-hook' for dmoffat.com ran with output:
 Deleting TXT record for dmoffat.com
 Found DNS record with ID: 1744875958
 Done deleting record

Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/dmoffat.com/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/dmoffat.com/privkey.pem
This certificate expires on 2024-10-02.
These files will be updated when the certificate renews.

NEXT STEPS:
- The certificate will need to be renewed before it expires. Certbot can automatically renew the certificate in the background, but you may need to take steps to enable that functionality. See https://certbot.org/renewal-setup for instructions.

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
If you like Certbot, please consider supporting our work by:
 * Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
 * Donating to EFF:                    https://eff.org/donate-le
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
```
Strangely this worked first try - now we just need to copy those certificate files into our repository and write some scripts to manage this process.

To copy the folders to the host (our computer), when we run the container, we'll mount a folder like so:

```bash
docker run --rm -it -v ./certs/:/certs dmoffat-letsencrypt
```

So now we have a folder inside the container which maps to one on our computer.

Inside `generate-certs`, we'll add some extra lines:

```bash
# Copy them to our mounted folder
cp -RL /etc/letsencrypt/live/dmoffat.com/* /certs/

# Make the private key readable
chmod a=r /certs/privkey.pem
```

Finally, we'll update our `Dockerfile` to execute `generate-certs` when the container starts:

```dockerfile
ENTRYPOINT ["bash", "/scripts/generate-certs"]
```

That's it - when we run:

```bash
docker run --rm -it -v ./certs/:/certs dmoffat-letsencrypt
```

Certbot will generate our certificates and put them in our local `certs` folder.

### Automating Docker commands

It's quite annoying having to run those `docker ...` commands manually to do these steps, so we'll write a quick script to automate this process:

```bash
#!/usr/bin/env bash

echo "Generating dmoffat.com certificates."

# Build the container
docker build --file dockerfiles/letsencrypt.dockerfile -t 'dmoffat-letsencrypt' .

if [[ "$?" != "0" ]]; then
    echo "error: Failed to build the Docker container which generates certificates"
    exit 1
fi

# Generate them
docker run --rm -it -v ./certs/:/certs dmoffat-letsencrypt

if [[ "$?" != "0" ]]; then
    echo "error: Failed to run the Docker container which generates certificates"
    exit 1
fi

echo "Certificates generated and available in ./certs/"
```

### Updating nginx to use SSL

Now we have our certs, we'll need to update the nginx config, let's add a new `server` block to our `http` block:

```
server {
    listen 8080;
    server_name dmoffat.com;
    return 301 https://www.$server_name$request_uri;
}
```

This block will redirect visits to dmoffat.com to www.dmoffat.com.

Then let's enable SSL in our other `server` block:

```
 server {
        listen 8443 ssl;
        server_name www.dmoffat.com;

        ssl_certificate     /certs/fullchain.pem;
        ssl_certificate_key /certs/privkey.pem;

        ... rest of config
 }
```

To make sure it's working, I added `dmoffat.com` and `www.dmoffat.com` to `/etc/hosts`, ran the nginx container and visited `https://www.dmoffat.com:8443` in my browser - it works.

I then wrote a script to build + run the nginx container (similar to the letsencrypt one):

```bash
#!/usr/bin/env bash

# Build the container
docker build --file dockerfiles/nginx.dockerfile -t 'dmoffat-nginx' .

# Start it
docker run --rm -it -p 8080:8080 -p 8443:8443 dmoffat-nginx
```

There's no error handling as this is just a local dev script to make sure my container build is working correctly.

### Pushing our container to DigitalOcean's container repository

To make the Docker container available on our server, we need to put it in a private container repository. We can't use a public container repository as our container contains sensitive information.

In the past I've created a private container repository on DigitalOcean, but have completely forgotten how you push to it.

DigitalOcean have a handy guide which involves the following steps:
- [Installing and configuring doctl](https://docs.digitalocean.com/reference/doctl/how-to/install/)
- Authenticate Docker with the registry
- Tag our local Docker image with a tag
- `docker push` to the tag

I wrote a script which looks like this:

```bash
#!/usr/bin/env bash

echo "Building and publishing nginx container."

# Ensure doctl is installed
if ! command -v doctl &> /dev/null; then
    echo "error: doctl not installed, install following: https://docs.digitalocean.com/reference/doctl/how-to/install/"
    exit 1
fi

# Authenticate with the repository
doctl registry login --never-expire

if [[ "$?" != "0" ]]; then
    echo "error: Failed to authenticate with the registry, see error above."
    exit 1 
fi

# Build the container
docker build --file dockerfiles/nginx.dockerfile -t 'dmoffat-nginx' .

if [[ "$?" != "0" ]]; then
    echo "error: Failed to build the Docker container, see error above."
    exit 1
fi

# Tag it
docker tag dmoffat-nginx registry.digitalocean.com/dmoffat/dmoffat-nginx:latest

# Push it to the container registry
docker push registry.digitalocean.com/dmoffat/dmoffat-nginx:latest

if [[ "$?" != "0" ]]; then
    echo "error: Failed to push image to DigitalOcean repository, see error above."
    exit 1
fi

echo "Done building and publishing nginx container"

```

Running it produces the correct output: 

```
$ ./build-publish-nginx 

Building and publishing nginx container.
[+] Building 11.5s (16/16) 
....
The push refers to repository [registry.digitalocean.com/dmoffat/dmoffat-nginx]
47245b9ed7f2: Layer already exists 
f752c313c2b2: Layer already exists 
c62362e184f8: Layer already exists 
a51b172d7184: Layer already exists 
b7486fe26981: Layer already exists 
320c8baef084: Layer already exists 
d2cef4a1b224: Layer already exists 
4275164ce225: Layer already exists 
6e92270dbfe6: Layer already exists 
b5d2e1fcf1ad: Layer already exists 
af9a70194aa4: Layer already exists 
latest: digest: sha256:7084888e1b6ac3e8133caca8b2aa06d0868152f2671d0dff068ca1dd58118b0a size: 2613
Done building and publishing nginx container
```

### Pulling the docker container on our server and running it

My VPS already has Docker installed and configured, so I just need to figure out how to pull the remote image from the container repository. At work we use Amazon's ECS, which manages pulling new container images and restarting containers - we don't have that luxury so will have to do it manually.

Reading the documentation the steps are:
- Authenticate with the container repository
- Pull the image from the repository
- Run the container

Because I didn't want to install `doctl` on my server, I just ran the following command to authenticate:

```bash
docker login \
    -u danmofo@gmail.com \
    -p DIGITALOCEAN_API_KEY \
    registry.digitalocean.com
```

Then to pull the image we can run:

```bash
docker pull registry.digitalocean.com/dmoffat/dmoffat-nginx:latest
```

And finally, to run the container:

```bash
# -d = Detached
# -p = map container port to host port (80 on host to 8080 on container)
docker run -d -p 80:8080 -p 443:8443 registry.digitalocean.com/dmoffat/dmoffat-nginx
```

Now we can check the container is running:

```bash
docker ps
```

which produces...

```
CONTAINER ID   IMAGE                                             COMMAND                  CREATED          STATUS          PORTS                                                                                    NAMES
5441e804bce7   registry.digitalocean.com/dmoffat/dmoffat-nginx   "/docker-entrypoint.…"   55 seconds ago   Up 54 seconds   80/tcp, 0.0.0.0:80->8080/tcp, :::80->8080/tcp, 0.0.0.0:443->8443/tcp, :::443->8443/tcp   upbeat_williams
```

GREAT! After all of that effort, we've finally got something running.

I now type `dmoffat.com` into my browser and I'm greeted with my website, running over HTTPS!

### Cleaning up

Running those steps each time we want to deploy is not fun. So let's write a script which we can run on our server to deploy our website.

This script is simple, it builds + publishes the container image, then connects to the server using SSH, then runs the commands mentioned above.

```bash
#!/usr/bin/env bash

# This script builds + deploys the website on my DigitalOcean VPS
# It assumes you've got SSH access, and a private key in ~/.ssh/do_dmoffat.com

echo "Deploying website..."

source .env

# Build and publish the nginx container
./build-publish-nginx

if [[ "$?" != "0" ]]; then
    echo "Failed to build + publish the nginx container."
    exit 1
fi

# Deploy it remotely
ssh -i ~/.ssh/do_dmoffat.com dmoffat.com -p 9999 /bin/bash << EOF
    echo "Authenticating with the registry"

    docker login -u danmofo@gmail.com -p $DIGITALOCEAN_API_KEY registry.digitalocean.com
    if [[ "$?" != "0" ]]; then
        echo "Failed to authenticate with container registry"
        exit 1
    fi

    echo "Pulling the container..."
    docker pull registry.digitalocean.com/dmoffat/dmoffat-nginx:latest
    if [[ "$?" != "0" ]]; then
        echo "Failed to pull container from container registry"
        exit 1
    fi
    
    echo "Killing existing container..."
    docker container kill dmoffat-nginx
    docker container rm dmoffat-nginx

    echo "Running new container..."
    docker run -d -p 80:8080 -p 443:8443 --name dmoffat-nginx registry.digitalocean.com/dmoffat/dmoffat-nginx
    if [[ "$?" != "0" ]]; then
        echo "Failed to start new container - website is currently down."
        exit 1
    fi
EOF
```

> **Side note:** This does produce a small amount of downtime after the container is killed and before the new one is started, but that's acceptable for a personal website.

It's pretty barebones, but does the job.

## Fin

And that's it, I've walked you through how I rebuilt my website from scratch and how I approached each aspect. Since this is just an initial version built in evenings during the week, I'm sure there are a lot of improvements that could be made, and over time I'll probably end up changing things, but for now, the website fulfills its initial purpose: a website where I can put information about myself, link to things I've created and write about things I'm interested in.

Here's a list of things I'd like to improve...

- **Images**
  - Getting Astro's `<Picture>` to produce the output I want and producing images with different pixel densities.
  - Exporting photos from GIMP with proper sizes. At the moment we're using Astro to resize/compress them using a source image that's way too big (original images are 1MB and 600kB)
- **Accessibility**
  - Make it actually accessible
- **Design**
  - Add some sort of navigation to the side bar
  - Impove typography and general design
  - Create my own favicon
- **CSS**
  - Explore new properties by looking at large websites
- **Deployment**
  - Clean up old container images as we're limited to a certain amount of space ([delete untaggged images](https://docs.digitalocean.com/products/container-registry/getting-started/quickstart/#manage-images-and-tags) and [garbage collection](https://docs.digitalocean.com/products/container-registry/how-to/clean-up-container-registry/))
  - Optimise Dockerfile so it only rebuilds when certain files changed, at the moment it's re-running astro build when a bash script changes, for example
- **Certificates**
  - Because they expire every 3 months, we need to manually renew them + deploy the website, we should write a script to do this


[Bye for now](https://www.youtube.com/watch?v=JgFvNzLAWtY)

---