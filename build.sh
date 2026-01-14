#!/bin/bash

# Ved Build Script

# Check if V is installed
if ! command -v v &> /dev/null
then
    echo "Error: V compiler not found."
    echo "Please install V from: https://github.com/vlang/v"
    exit 1
fi

# Default output name
OUT="ved"

# Help message
show_help() {
    echo "Usage: ./build.sh [options]"
    echo "Options:"
    echo "  -p, --prod       Build in production mode (optimized)"
    echo "  -f, --freetype   Build with freetype support"
    echo "  -h, --help       Show this help message"
}

V_FLAGS=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -p|--prod) V_FLAGS="$V_FLAGS -prod"; shift ;;
        -f|--freetype) V_FLAGS="$V_FLAGS -d use_freetype"; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
done

echo "Compiling Ved with flags: $V_FLAGS"
v $V_FLAGS -o "$OUT" .

if [ $? -eq 0 ]; then
    echo "---------------------------------------"
    echo "Build successful! Executable created: $OUT"
    echo "Run it with: ./$OUT"
else
    echo "---------------------------------------"
    echo "Build failed."
    exit 1
fi
