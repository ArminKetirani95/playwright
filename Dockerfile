# Use the official Node.js image with version 18
FROM node:18-bullseye

# Set the working directory inside the container
WORKDIR /usr/src/app

# Install Playwright dependencies for Chromium, Firefox, and WebKit
RUN apt-get update && apt-get install -y \
    libnss3 \
    libatk-bridge2.0-0 \
    libxcomposite1 \
    libxrandr2 \
    libxdamage1 \
    libgbm1 \
    libasound2 \
    libpangocairo-1.0-0 \
    libxshmfence1 \
    libgtk-3-0 \
    libx11-xcb1

# Copy package.json and package-lock.json to install dependencies
COPY package*.json ./

# Install npm dependencies
RUN npm ci

# Install Playwright browsers
RUN npx playwright install --with-deps

# Copy all the source code to the container
COPY . .

# Set environment variable for CI mode
ENV CI=true

# Run Playwright tests
CMD ["npx", "playwright", "test"]