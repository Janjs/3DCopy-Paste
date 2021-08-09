from flask import Flask
import os
from lidar import lidar
from photogrammetry import photogrammetry

app = Flask(__name__)
app.register_blueprint(lidar)
app.register_blueprint(photogrammetry)

@app.route("/")
def hello():
    return "3D Cut&Paste"

if __name__ == '__main__':
    os.environ['FLASK_ENV'] = 'development'
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)