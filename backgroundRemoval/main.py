import io
import os
import sys
from flask import Flask, request, send_file, jsonify
from flask_cors import CORS
from PIL import Image
import numpy as np
import time
import logging

import u2net

logging.basicConfig(level=logging.INFO)

# Initialize the Flask application
app = Flask(__name__)
CORS(app)


# Simple probe.
@app.route('/removebg', methods=['GET'])
def hello():
    return {'msg': 'Hello U^2-Net!'}


# Route http posts to this method
@app.route('/removebg', methods=['POST'])
def run():
    start = time.time()

    # Convert string of image data to uint8
    if 'data' not in request.files:
        return jsonify({'error': 'missing file param `data`'}), 400
    data = request.files['data'].read()
    if len(data) == 0:
        return jsonify({'error': 'empty image'}), 400

    # Convert string data to PIL Image
    img = Image.open(io.BytesIO(data))

    # Ensure i,qge size is under 1024
    if img.size[0] > 1024 or img.size[1] > 1024:
        img.thumbnail((1024, 1024))

    # Process Image
    res = u2net.run(np.array(img))
    
    # Save to buffer
    buff = io.BytesIO()
    res.save(buff, 'PNG')
    buff.seek(0)

    # Print stats
    logging.info(f'Completed in {time.time() - start:.2f}s')

    # Return data
    return send_file(buff, mimetype='image/png')


def naive_cutout(img, mask):
    empty = Image.new("RGBA", (img.size), 0)
    cutout = Image.composite(img, empty, mask.resize(img.size, Image.LANCZOS))
    return cutout


def backgroundRemoval(image_path):
    start = time.time()

    # Get original dataset 
    img = Image.open("./original_dataset/"+image_path)

    # Process Image
    mask = u2net.run(np.array(img)).convert("L")

    # masking
    img_bg_removed = naive_cutout(img, mask)
    ## convert to JPG
    #img_bg_removed = img_bg_removed.convert('RGB') 
    img_bg_removed.save("./output_dataset_png/"+image_path.split(".")[0]+".png")

    # Print stats
    logging.info(f'{image_path} Completed in {time.time() - start:.2f}s')

def manualRemoval():
    start = time.time()
    images_paths = os.listdir("./original_dataset")
    for image_path in images_paths:
        backgroundRemoval(image_path)
    # Print stats
    logging.info(f'{len(images_paths)} images done! in {time.time() - start:.2f}s')



if __name__ == '__main__':
    manual = True
    if manual:
        manualRemoval()
    else:
        os.environ['FLASK_ENV'] = 'development'
        port = int(os.environ.get('PORT', 8081))
        app.run(debug=True, host='localhost', port=port)
