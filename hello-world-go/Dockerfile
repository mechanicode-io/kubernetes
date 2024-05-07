# Use a minimal base image for efficiency
FROM golang:alpine AS builder

# Set working directory for the build stage
WORKDIR /app/builder

# Copy your source code (replace "your-app-dir" with "app")
COPY app .

# Install dependencies (if any) and build the application
RUN go mod init azinterview-go
RUN go mod tidy
RUN go get azinterview-go
RUN go build -o main ./...

# Use a smaller image for the final container
FROM alpine

# Set working directory for the final stage
WORKDIR /app

# Create the mechanicode user with UID and GID 1337
RUN adduser -D -u 1337 -g 1337 mechanicode

RUN apk add --no-cache docker kubectl
# Copy the built binary from the builder stage
COPY --from=builder /app/builder/main /app/main

# Copy static files
COPY app/ /app/

# Expose the port your application listens on (replace 9000 with your actual port)
EXPOSE 8080

# Change ownership of the application directory to the mechanicode user
RUN chown -R mechanicode: /app

# Switch to the mechanicode user
USER mechanicode

# Set the command to run your application
CMD ["/app/main"]
