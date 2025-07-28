#!/bin/bash

# Build Docker image if it doesn't exist
docker build -f Dockerfile.slither -t slither-analyzer .

# Run Slither analysis in interactive mode
docker run -it -v $(pwd):/code slither-analyzer
