# Use an official Python runtime as a parent image
FROM python:latest

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . ./

# System prerequisites
RUN apt-get update

# Install dependencies including Rust
RUN apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    gettext \
    vim \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . "$HOME/.cargo/env" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Poetry
RUN pip install poetry

# Project initialization
RUN poetry config virtualenvs.create false \
    && poetry install --no-interaction --no-ansi

# Define the command to run the application
CMD ["python", "-u", "main.py"]
