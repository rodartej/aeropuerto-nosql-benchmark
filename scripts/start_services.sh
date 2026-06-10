#!/usr/bin/env bash
# Arranca servicios locales para reproducir benchmarks
brew services start postgresql@15
brew services start mongodb-community
brew services start neo4j
