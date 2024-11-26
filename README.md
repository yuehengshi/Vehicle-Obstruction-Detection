# Vehicle and Obstruction Detection Using YOLOv8s in iOS Capture App

## Overview

This project integrates a machine learning (ML) model, **YOLOv8s**, into a mobile capture app to detect vehicles and obstructions. The goal is to optimize the ML model for size and performance while accurately identifying and responding to specific objects. The app provides users with a stencil for aligning vehicles in the correct position and size.

---

## Features

- **Vehicle Detection**:
  - Detects objects identified as "car" or "truck" from the ML model's results.
  - Filters out non-relevant objects.
  - Identifies the largest vehicle (based on bounding box area) and highlights it.

- **Obstruction Detection**:
  - Uses detected objects that are not "car" or "truck" to identify obstructions.
  - Checks for overlaps or intersections between the obstruction and the vehicle.
  - Implements additional logic to avoid false positives due to large or unstable detection sizes.

- **Stencil Interaction**:
  - Provides a stencil guide to help users position vehicles correctly.
  - Verifies the vehicle's alignment and size relative to the stencil using specific threshold rules.

---

## ML Model Integration

- **Model**: YOLOv8s (CoreML format)
- **Model Size**: 22.4 MB
- **Object Classes**: 80 predefined classes (e.g., car, truck, person, etc.)
- **Integration Steps**:
  1. Filter results for relevant identifiers: `car` and `truck`.
  2. Extract position and size information for bounding boxes.
  3. Apply detection logic for vehicles and obstructions.

---

## Demo

https://github.com/user-attachments/assets/1d7e72fb-ed46-43a5-884f-eabc4c8988cf

