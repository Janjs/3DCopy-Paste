import io
import os
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from PIL import Image
import numpy as np
import time
import screenpoint
from datetime import datetime
import pyscreenshot
import requests
import logging
import json

logging.basicConfig(level=logging.INFO)

max_view_size = 700
max_screenshot_size = 400

# Initialize the Flask application.
app = Flask(__name__)
CORS(app)


# Simple probe.
@app.route('/', methods=['GET'])
def hello():
    return 'Hello AR Cut Paste!'

# The cut endpoints performs the salience detection / background removal.
# And store a copy of the result to be pasted later.
@app.route('/paste', methods=['POST'])
def save():
    start = time.time()
    logging.info(' PASTE')

    # Convert string of image data to uint8.
    if 'data' not in request.files:
        return jsonify({
            'status': 'error',
            'error': 'missing file param `data`'
        }), 400
    data = request.files['data'].read()
    if len(data) == 0:
        return jsonify({'status:': 'error', 'error': 'empty image'}), 400

    # Save debug locally.
    with open('cut_received.jpg', 'wb') as f:
        f.write(data)

     # Convert string data to PIL Image.
    logging.info(' > loading image...')
    view = Image.open(io.BytesIO(data))

    # Ensure the view image size is under max_view_size.
    if view.size[0] > max_view_size or view.size[1] > max_view_size:
        view.thumbnail((max_view_size, max_view_size))

    # Take screenshot with pyscreenshot.
    logging.info(' > grabbing screenshot...')
    screen = pyscreenshot.grab()
    screen_width, screen_height = screen.size

    # Ensure screenshot is under max size.
    if screen.size[0] > max_screenshot_size or screen.size[1] > max_screenshot_size:
        screen.thumbnail((max_screenshot_size, max_screenshot_size))

    # Finds view centroid coordinates in screen space.
    logging.info(' > finding projected point...')
    view_arr = np.array(view.convert('L'))
    screen_arr = np.array(screen.convert('L'))
    # logging.info(f'{view_arr.shape}, {screen_arr.shape}')
    x, y = screenpoint.project(view_arr, screen_arr, False)

    found = x != -1 and y != -1

    if found:
        # Bring back to screen space
        x = int(x / screen.size[0] * screen_width)
        y = int(y / screen.size[1] * screen_height)
        logging.info(f'{x}, {y}')

        # Paste the current model in blender at these coordinates.
        logging.info(' > sending to blender...')

        # creating coordinates
        data = {
            'x': x,
            'y': y
        }

        # write coordinates 
        with open('/Users/janjimenezserra/Desktop/dissertation/3DCut&Paste/scans/coordinates.json', 'w') as outfile:
            json.dump(data, outfile)

        os.replace("/Users/janjimenezserra/Downloads/model.obj", "/Users/janjimenezserra/Desktop/dissertation/3DCut&Paste/scans/scan.obj")
        
    else:
        logging.info('screen not found')

    # Print stats
    logging.info(f'Completed in {time.time() - start:.2f}s')

    # Return status.
    if found:
        return jsonify({'status': 'ok'})
    else:
        return jsonify({'status': 'screen not found'})


if __name__ == '__main__':
    os.environ['FLASK_ENV'] = 'development'
    port = int(os.environ.get('PORT', 8080))
    app.run(host='192.168.2.3', port=port)
