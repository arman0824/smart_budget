FROM alpine:3.20.3

# Linux can validate the repository shape and documented project settings, but
# it does not contain Apple's SDKs and must not attempt an iOS build.
RUN apk add --no-cache make

WORKDIR /workspace
COPY Makefile README.md ./
COPY Dockerfile ./
COPY app.xcodeproj/project.pbxproj ./app.xcodeproj/project.pbxproj
COPY app/ ./app/

ENV SOURCE_ONLY=1

RUN make test
CMD ["make", "test"]
