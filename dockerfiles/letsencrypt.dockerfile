FROM alpine:3.20.1

RUN apk add certbot curl jq bash

# Copy our API key
COPY .env /.env

# Copy scripts to create/delete TXT records
COPY scripts/create-txt-record /scripts/
COPY scripts/delete-txt-record /scripts/
COPY scripts/generate-certs /scripts/

# Run the script
ENTRYPOINT ["bash", "/scripts/generate-certs"]