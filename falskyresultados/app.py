import os
from flask import Flask, request, jsonify
import torch
from ultralytics import YOLO
import cv2
import numpy as np
import json
import music21 as m21
import time

app = Flask(__name__)

# Cargar el modelo YOLO
model = YOLO("models/best.pt")

# Mapa de clases
CLASS_MAP = {
    0: "barradecompas",
    1: "blanca",
    2: "clavedefa",
    3: "clavedesol",
    4: "corchea",
    5: "negra",
    6: "semicorchea"
}

@app.route('/detect', methods=['POST'])
def detect():
    if 'image' not in request.files:
        return jsonify({"error": "No image part"}), 400

    file = request.files['image']
    image = cv2.imdecode(np.frombuffer(file.read(), np.uint8), cv2.IMREAD_COLOR)

    recognized_notes = process_image(image)

    return jsonify({"notes": recognized_notes})

def process_image(image):
    results = model(image)
    recognized_notes = []
    for result in results:
        for box, cls in zip(result.boxes.xyxy, result.boxes.cls):
            x1, y1, x2, y2 = map(int, box[:4])
            cls = int(cls.item())
            print(f'Detected: {CLASS_MAP[cls]} at ({x1}, {y1}, {x2}, {y2})')  # Debug print
            recognized_notes.append({
                "x1": x1, "y1": y1, "x2": x2, "y2": y2, "class": CLASS_MAP[cls]
            })
    # Ordenar las notas por su posición x (de izquierda a derecha)
    recognized_notes.sort(key=lambda note: note['x1'])
    return recognized_notes


@app.route('/convert', methods=['POST'])
def convert():
    data = request.get_json()
    if not data or 'notes' not in data:
        return jsonify({"error": "Invalid input"}), 400

    notes = data['notes']
    score = m21.stream.Score()
    part = None

    for note in notes:
        note_class = note['class']
        print(f'Processing note: {note_class}')  # Debug print
        
        if note_class == "clavedesol" or note_class == "clavedefa":
            if part:
                score.append(part)
            part = m21.stream.Part()
            if note_class == "clavedesol":
                part.insert(0, m21.clef.TrebleClef())
            elif note_class == "clavedefa":
                part.insert(0, m21.clef.BassClef())
            ts = m21.meter.TimeSignature('4/4')
            part.insert(0, ts)

        elif part:
            if note_class == "negra":
                n = m21.note.Note()
                n.quarterLength = 1.0
            elif note_class == "blanca":
                n = m21.note.Note()
                n.quarterLength = 2.0
            elif note_class == "corchea":
                n = m21.note.Note()
                n.quarterLength = 0.5
            elif note_class == "semicorchea":
                n = m21.note.Note()
                n.quarterLength = 0.25
            else:
                continue
            part.append(n)

    if part:
        score.append(part)
    
    output_dir = 'E:\\Ultimoentrenamiento\\salidas'
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Crear un nombre de archivo único basado en la marca de tiempo
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    output_path = os.path.join(output_dir, f'asmusic_{timestamp}.xml')
    score.write('musicxml', fp=output_path)

    print(f'XML saved to {output_path}')  # Debug print
    return jsonify({"message": "XML file created successfully", "path": output_path})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
