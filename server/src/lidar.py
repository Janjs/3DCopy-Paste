import io
import os
from flask import Flask, request, jsonify, Blueprint
from flask_cors import CORS
from PIL import Image
import numpy as np
import time
import screenpoint
import pyscreenshot
import logging
import json
import cv2

logging.basicConfig(level=logging.INFO)

max_view_size = 700
max_screenshot_size = 400

# Initialize the Flask application.
app = Flask(__name__)
CORS(app)

DOWNLOADS_LOC = "####"

lidar = Blueprint('lidar',__name__)
@lidar.route("/lidar")
def hello():
    return "Hello World from lidar!"

# The paste endpoint performs the salience detection / background removal.
# And store a copy of the result to be pasted later.
@lidar.route('/lidar/paste', methods=['POST'])
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
    with open('view_received.jpg', 'wb') as f:
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
    x, y, img_debug = screenpoint.project(view_arr, screen_arr, True)

    # Write debug image.
    cv2.imwrite('feature_matching.png', img_debug)

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
        with open('./scans/coordinates.json', 'w') as outfile:
            json.dump(data, outfile)

        os.replace(DOWNLOADS_LOC+"/model.obj",
                   "./scans/model.obj")

    else:
        logging.info('screen not found')

    # Print stats
    logging.info(f'Completed in {time.time() - start:.2f}s')

    # Return status.
    if found:
        return jsonify({'status': 'ok'})
    else:
        return jsonify({'status': 'screen not found'})


