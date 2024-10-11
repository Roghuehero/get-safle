# Use the official Node.js image as the base image
FROM node:21

# Create a non-root user and group
RUN groupadd -g 1001 appgroup && \
    useradd -m -u 1001 -g appgroup appuser

# Set the working directory
WORKDIR /usr/src/app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy the rest of the application code
COPY . .

# Change ownership of the app directory to the non-root user
RUN chown -R appuser:appgroup /usr/src/app

# Switch to the non-root user
USER appuser

# Expose the application port
EXPOSE 3000

# Command to run the application
CMD ["node", "server.js"]
