import json

data = {
    'x': 0.0,
    'y': 10.0
}

# write coordinates 
with open('./scans/coordinates.json', 'w') as outfile:
    json.dump(data, outfile)
