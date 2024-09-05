# Stage 1: Build Stage
FROM node:18-alpine AS base

# Set the working directory
WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies, including dev dependencies for TypeScript
RUN npm install

# Copy the rest of the application files
COPY tsconfig.json ./
COPY index.ts ./

# Install TypeScript and types for express and node
RUN npm install --save-dev typescript @types/node @types/express

# Build the TypeScript code
RUN npm run build

# Stage 2: Production Image
FROM node:18-alpine

WORKDIR /app

# Copy only the dependencies and compiled JavaScript from the first stage
COPY --from=base /app/node_modules /app/node_modules
COPY --from=base /app/package*.json ./
COPY --from=base /app/dist /app/dist

# Create a non-root user and switch to it
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Add arguments for AWS credentials and default bucket name (can be overridden by environment variables)
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ARG AWS_REGION="us-west-2"
ARG BUCKET_NAME="unleashtest-123123"

# Set environment variables for AWS credentials and bucket configuration
ENV AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
ENV AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
ENV AWS_REGION=${AWS_REGION}

ENV BUCKET_NAME=${BUCKET_NAME}
ENV PORT=3000

EXPOSE $PORT

# Start the Node.js server
CMD ["node", "dist/index.js"]
