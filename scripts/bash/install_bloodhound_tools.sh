#!/bin/bash

# Variables
TOOLS_DIR=~/tools

# Install BloodHound
echo "Cloning BloodHound repository..."
git clone https://github.com/BloodHoundAD/BloodHound.git $TOOLS_DIR/BloodHound

# Install BloodHound dependencies
echo "Installing BloodHound dependencies..."
cd $TOOLS_DIR/BloodHound
npm install --legacy-peer-deps

# Build BloodHound
echo "Building BloodHound..."
npm run build

# Install Python Collector
echo "Cloning Python Collector repository..."
git clone https://github.com/BloodHoundAD/python-collector.git $TOOLS_DIR/python-collector

# Set up Python Collector virtual environment
echo "Setting up Python Collector virtual environment..."
cd $TOOLS_DIR/python-collector
python3 -m venv collector-env
source collector-env/bin/activate

# Install Python Collector dependencies
echo "Installing Python Collector dependencies..."
pip install -r requirements.txt

# Feedback to the user
echo "BloodHound and Python Collector installation complete!"
echo "BloodHound is located at $TOOLS_DIR/BloodHound"
echo "Python Collector is located at $TOOLS_DIR/python-collector"
echo "Activate Python Collector environment by running 'source $TOOLS_DIR/python-collector/collector-env/bin/activate'"
echo "You can run BloodHound with 'npm start' and Python Collector with 'python3 collector.py'"

# Done
echo "Setup complete!"
