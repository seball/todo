#!/bin/bash
set -e
sudo apt update
sudo apt install -y nodejs npm git unzip
cd backend
npm install express body-parser
