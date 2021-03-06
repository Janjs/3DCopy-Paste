import io
from flask import request, send_file, jsonify, Blueprint
from flask.helpers import url_for
from PIL import Image
import numpy as np
import time
import logging
import requests
import u2net
import subprocess

photogrammetry = Blueprint('photogrammetry',__name__)
@photogrammetry.route("/photogrammetry")
def hello():
    return "Hello World from photogrammetry!"

# Route http posts to this method
@photogrammetry.route('/photogrammetry/removebg', methods=['POST'])
def run():
    start = time.time()

    fromPhone = False
    
    if 'data[0]' in request.files:
        fromPhone = True

    # Convert string of image data to uint8
    if 'data[]' not in request.files and not(fromPhone):
        print("hi")
        return jsonify({'error': 'missing file param `data`'}), 400
    
    images = []
    if fromPhone:
        for i in range(len(request.files)):
            images.append(request.files.get(f"data[{i}]"))
    else: 
        images = request.files if fromPhone else request.files.getlist("data[]")

    if len(images) == 0:
        return jsonify({'error': 'empty image'}), 400

    print(images)

    for image in images:
        filename = image.filename
        image_data = image.read()

        # Convert string data to PIL Image
        img = Image.open(io.BytesIO(image_data))

        # Ensure i,qge size is under 1024
        if img.size[0] > 1024 or img.size[1] > 1024:
            img.thumbnail((1024, 1024))

        # Process Image
        mask = u2net.run(np.array(img)).convert("L")

        # masking
        img_bg_removed = naive_cutout(img, mask)
        img_bg_removed.save("bg_removed_dataset/"+filename.split(".")[0]+".png")
    
    # generate 3D object with Meshroom 
    generate3Dmodel()

    # Print stats
    logging.info(f'Completed in {time.time() - start:.2f}s')
    
    resp = jsonify(success=True)
    return resp

def naive_cutout(img, mask):
    empty = Image.new("RGBA", (img.size), 0)
    cutout = Image.composite(img, empty, mask.resize(img.size, Image.LANCZOS))
    return cutout

def handleFromPhoneRequest():
    pass

def generate3Dmodel():
    # Using meshroom as of now, trying to get a cloud photogrammetry version working for future versions.
    # bashCmd = r"C:\Users\Usuario\Documents\JAN\GitHub\meshroomApp\meshroom_batch.exe --input C:\Users\Usuario\Documents\JAN\GitHub\3DCopy-Paste\server\bg_removed_dataset --output C:\Users\Usuario\Documents\JAN\GitHub\3DCopy-Paste\scans"
    process = subprocess.Popen(bashCmd)
    stoud, stderr = process.communicate()
