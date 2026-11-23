#!/usr/bin/env bash

nvidia-smi
nvcc --version
nvidia-smi --query-gpu=name,driver_version,memory.total,memory.free,temperature.gpu,utilization.gpu --format=csv
