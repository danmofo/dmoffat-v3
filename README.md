# dmoffat.com (version 3)

This is version 3 of my personal website, built with Astro, currently deployed on [https://www.dmoffat.com](https://www.dmoffat.com).


## Prerequisites

You need the following software to develop and build the website:
- Node + npm (v18+)

You need the following software to deploy the website:
- Docker
- `jq`
- `doctl` - you'll need a DigitalOcean access key for this with 'domain' and 'registry' permissions

Some scripts will check for the existence of this software and tell you if it's missing, but some will not!

## Developing

Install the dependencies:

```bash
npm i
```

This command starts the Astro dev server in host mode (so you can open on your mobile device too):

```bash
npm run dev -- --host
```

If you're making changes to the nginx container that runs the website, or more substantial Astro changes, it's probably best to run this and make sure it's ok:

```bash
./build-run-nginx
```

This will build and run the website inside nginx locally (ports 8080 (http) and 8443 (https)). This is identical to how it runs on the production environment.

## Deploying

To deploy, you'll need:
- SSH access for dmoffat.com
- Make sure `.env` contains the things in `.env.template` with relevant values

To deploy:

```bash
./deploy
```

The script will tell you if anything went wrong and what to do.

### Generating new certificates

Certificates expire every three months, run the following (followed by a deploy) to renew them:

```bash
./generate-dmoffat-certs
```

Certs get placed in the `certs` folder, run a deployment afterwards to put them live.