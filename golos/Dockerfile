ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

RUN apk add --no-cache python3 py3-aiohttp tzdata

COPY golos.py /golos/golos.py

EXPOSE 8790

CMD [ "python3", "-u", "/golos/golos.py" ]
